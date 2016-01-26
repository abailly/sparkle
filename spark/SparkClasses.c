#include <jni.h>
#include <stdio.h>
#include "HaskellRTS.h"
#include "JVM.h"
#include "SparkClasses.h"

JNIEnv* jniEnv()
{
  JNIEnv* env;
  int envStat = (*jvm)->GetEnv(jvm, (void**)&env, JNI_VERSION_1_6);
  if(envStat == JNI_EDETACHED)
    (*jvm)->AttachCurrentThread(jvm, (void**)& env, NULL);
  return env;
}

jclass findClass(const char* java_class)
{
  JNIEnv* env = jniEnv();
  jclass class = (*env)->FindClass(env, java_class);
  if(!class)
  {
    printf("!! sparkle: Couldn't find Java class %s\n", java_class);
    return NULL;
  }
  return class;
}

jmethodID findMethod(jclass java_class, const char* method_name, const char* sig)
{
  JNIEnv* env = jniEnv();
  jmethodID mid = (*env)->GetMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jmethodID findStaticMethod(jclass java_class, const char* method_name, const char* sig)
{
  JNIEnv* env = jniEnv();
  jmethodID mid = (*env)->GetStaticMethodID(env, java_class, method_name, sig);
  if(!mid)
  {
    printf("!! sparkle: Couldn't find static method %s with signature %s", method_name, sig);
    return NULL;
  }
  return mid;
}

jobject callObjectMethod(jobject obj, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
  jobject res = (*env)->CallObjectMethodA(env, obj, method, args);
  /*
  if(!res)
  {
    printf("!! sparkle: callObjectMethod returned NULL\n");
    return NULL;
  }
  */

  return res;
}

jobject callStaticObjectMethod(jclass java_class, jmethodID method, jvalue* args)
{
  JNIEnv* env = jniEnv();
  jobject res = (*env)->CallStaticObjectMethodA(env, java_class, method, args);
  /*
  if(!res)
  {
    printf("!! sparkle: callStaticObjectMethod returned NULL\n");
    return NULL;
  }
  */

  return res;
}

jobject newObject(jclass java_class, const char* sig, const jvalue* args)
{
  JNIEnv* env = jniEnv();
  jmethodID constr;
  jobject obj;

  constr = findMethod(java_class, "<init>", sig);

  obj = (*env)->NewObjectA(env, java_class, constr, args);
  if(!obj)
  {
    printf("!! sparkle: Constructor with signature %s failed\n", sig);
    return NULL;
  }

  return obj;
}

jstring newString(const char* str)
{
  JNIEnv* env = jniEnv();
  return (*env)->NewStringUTF(env, str);
}

jintArray newIntArray(size_t size, int* data)
{
  JNIEnv* env = jniEnv();
  jintArray arr = (*env)->NewIntArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jintArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetIntArrayRegion(env, arr, 0, size, data);
  return arr;
}

jbyteArray newByteArray(size_t size, jbyte* data)
{
  JNIEnv* env = jniEnv();
  jbyteArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jbyteArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetByteArrayRegion(env, arr, 0, size, data);
  return arr;
}

jdoubleArray newDoubleArray(size_t size, jdouble* data)
{
  JNIEnv* env = jniEnv();
  jdoubleArray arr = (*env)->NewByteArray(env, size);
  if(!arr)
  {
    printf("!! sparkle: jdoubleArray of size %zd cannot be allocated", size);
    return NULL;
  }

  (*env)->SetDoubleArrayRegion(env, arr, 0, size, data);
  return arr;
}

jobject newSparkConf(const char* appname)
{
  jclass spark_conf_class = findClass("org/apache/spark/SparkConf");
  jmethodID spark_conf_set_appname =
    findMethod(spark_conf_class, "setAppName", "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;");
  jobject conf = newObject(spark_conf_class, "()V", NULL);
  jstring jappname = newString(appname);

  callObjectMethod(conf, spark_conf_set_appname, &jappname);

  return conf;
}

jobject newSparkContext(jobject sparkConf)
{
  jvalue arg;
  arg.l = sparkConf;

  jobject spark_ctx =
    newObject(findClass("org/apache/spark/api/java/JavaSparkContext"), "(Lorg/apache/spark/SparkConf;)V", &arg);

  return spark_ctx;
}

jobject parallelize(jobject sparkContext, jint* data, size_t data_length)
{
  JNIEnv* env = jniEnv();
  jclass spark_helper_class = findClass("Helper");
  jmethodID spark_helper_parallelize =
    findStaticMethod(spark_helper_class, "parallelize", "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;");
  jintArray finalData = newIntArray(data_length, data);
  jvalue args[2];
  args[0].l = sparkContext;
  args[1].l = finalData;

  jobject resultRDD = callStaticObjectMethod(spark_helper_class, spark_helper_parallelize, args);

  if(resultRDD == NULL)
  { 
    printf("!! sparkle: parallelize() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return NULL;
    }
  }

  return resultRDD;
}

void collect(jobject rdd, int** buf, size_t* len)
{
  JNIEnv* env = jniEnv();
  jclass spark_helper_class = findClass("Helper");
  jmethodID spark_helper_collect =
    findStaticMethod(spark_helper_class, "collect", "(Lorg/apache/spark/api/java/JavaRDD;)[I");
  jvalue arg;
  arg.l = rdd;
  jintArray elements = callStaticObjectMethod(spark_helper_class, spark_helper_collect, &arg);
  if(elements == NULL)
  {
    printf("!! sparkle: collect() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return;
    }
  }

  *len = (*env)->GetArrayLength(env, elements);

  int* finalArr = (int*) malloc((*len) * sizeof(int));
  finalArr = (*env)->GetIntArrayElements(env, elements, NULL);

  *buf = finalArr;
}

jobject rddmap(jobject rdd, char* clos, long closSize)
{
  JNIEnv* env = jniEnv();
  jbyteArray closArr = newByteArray(closSize, clos);
  jclass spark_helper_class = findClass("Helper");
  jmethodID spark_helper_map =
    findStaticMethod(spark_helper_class, "map", "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;");

  jvalue args[2];
  args[0].l = rdd;
  args[1].l = closArr;

  jobject resultRDD = callStaticObjectMethod(spark_helper_class, spark_helper_map, args);
  if(resultRDD == NULL)
  {
    printf("!! sparkle: map() returned NULL\n");
    jthrowable exc;
    exc = (*env)->ExceptionOccurred(env);
    if(exc)
    {
      (*env)->ExceptionDescribe(env);
      (*env)->ExceptionClear(env);
      return NULL;
    }
  }

  return resultRDD;
}