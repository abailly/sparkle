{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

module Foreign.Java
  ( JVM
  , JNIEnv
  , JObject
  , JClass
  , JMethodID
  , JFieldID
  , JString
  , JIntArray
  , JByteArray
  , JDoubleArray
  , JObjectArray
  , JValue(..)
  , findClass
  , newObject
  , getFieldID
  , getObjectField
  , getMethodID
  , getStaticMethodID
  , callObjectMethod
  , callBooleanMethod
  , callIntMethod
  , callLongMethod
  , callByteMethod
  , callDoubleMethod
  , callVoidMethod
  , callStaticObjectMethod
  , callStaticVoidMethod
  , newIntArray
  , newDoubleArray
  , newByteArray
  , newObjectArray
  , newStringUTF
  , getArrayLength
  , getStringUTFLength
  , getIntArrayElements
  , getByteArrayElements
  , getDoubleArrayElements
  , getStringUTFChars
  , setIntArrayRegion
  , setByteArrayRegion
  , setDoubleArrayRegion
  , releaseStringUTFChars
  ) where

import Control.Exception (Exception, throwIO)
import Data.Int
import Data.Word
import Data.ByteString (ByteString)
import Data.Monoid ((<>))
import Data.Typeable (Typeable)
import Foreign.C (CChar, withCString)
import Foreign.Java.Types
import Foreign.Marshal.Array
import Foreign.Ptr (Ptr, nullPtr)
import qualified Language.C.Inline as C
import qualified Language.C.Inline.Unsafe as CU

C.context (C.baseCtx <> C.bsCtx <> jniCtx)

C.include "<jni.h>"

data JavaException = JavaException JThrowable
  deriving (Show, Typeable)

instance Exception JavaException

-- | Map Java exceptions to Haskell exceptions.
throwIfException :: Ptr JNIEnv -> IO a -> IO a
throwIfException env m = do
    x <- m
    JObject_ excptr <- [CU.exp| jthrowable { (*$(JNIEnv *env))->ExceptionOccurred($(JNIEnv *env)) } |]
    if excptr == nullPtr
    then return x
    else do
      [CU.exp| void { (*$(JNIEnv *env))->ExceptionDescribe($(JNIEnv *env)) } |]
      throwIO $ JavaException (JObject_ excptr)

findClass :: JNIEnv -> ByteString -> IO JObject
findClass (JNIEnv_ env) name =
    throwIfException env $
    [C.exp| jclass { (*$(JNIEnv *env))->FindClass($(JNIEnv *env), $bs-ptr:name) } |]

newObject :: JNIEnv -> JClass -> ByteString -> [JValue] -> IO JObject
newObject (JNIEnv_ env) cls sig args =
    throwIfException env $
    withArray args $ \cargs -> do
      constr <- getMethodID (JNIEnv_ env) cls "<init>" sig
      [CU.exp| jclass {
        (*$(JNIEnv *env))->NewObjectA($(JNIEnv *env),
                                      $(jclass cls),
                                      $(jmethodID constr),
                                      $(jvalue *cargs)) } |]

getFieldID :: JNIEnv -> JClass -> ByteString -> ByteString -> IO JFieldID
getFieldID (JNIEnv_ env) cls fieldname sig =
    throwIfException env $
    [CU.exp| jfieldID {
      (*$(JNIEnv *env))->GetFieldID($(JNIEnv *env),
                                    $(jclass cls),
                                    $bs-ptr:fieldname,
                                    $bs-ptr:sig) } |]

getObjectField :: JNIEnv -> JObject -> JFieldID -> IO JObject
getObjectField (JNIEnv_ env) obj field =
    throwIfException env $
    [CU.exp| jobject {
      (*$(JNIEnv *env))->GetObjectField($(JNIEnv *env),
                                        $(jobject obj),
                                        $(jfieldID field)) } |]

getMethodID :: JNIEnv -> JClass -> ByteString -> ByteString -> IO JMethodID
getMethodID (JNIEnv_ env) cls methodname sig =
    throwIfException env $
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetMethodID($(JNIEnv *env),
                                     $(jclass cls),
                                     $bs-ptr:methodname,
                                     $bs-ptr:sig) } |]

getStaticMethodID :: JNIEnv -> JClass -> ByteString -> ByteString -> IO JMethodID
getStaticMethodID (JNIEnv_ env) cls methodname sig =
    throwIfException env $
    [CU.exp| jmethodID {
      (*$(JNIEnv *env))->GetStaticMethodID($(JNIEnv *env),
                                           $(jclass cls),
                                           $bs-ptr:methodname,
                                           $bs-ptr:sig) } |]

callObjectMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO JObject
callObjectMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jobject {
      (*$(JNIEnv *env))->CallObjectMethodA($(JNIEnv *env),
                                           $(jobject obj),
                                           $(jmethodID method),
                                           $(jvalue *cargs)) } |]

callBooleanMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO Word8
callBooleanMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jboolean {
      (*$(JNIEnv *env))->CallBooleanMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callIntMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO Int32
callIntMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jint {
      (*$(JNIEnv *env))->CallIntMethodA($(JNIEnv *env),
                                        $(jobject obj),
                                        $(jmethodID method),
                                        $(jvalue *cargs)) } |]

callLongMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO Int64
callLongMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jlong {
      (*$(JNIEnv *env))->CallLongMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callByteMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO CChar
callByteMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jbyte {
      (*$(JNIEnv *env))->CallByteMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callDoubleMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO Double
callDoubleMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jdouble {
      (*$(JNIEnv *env))->CallDoubleMethodA($(JNIEnv *env),
                                           $(jobject obj),
                                           $(jmethodID method),
                                           $(jvalue *cargs)) } |]

callVoidMethod :: JNIEnv -> JObject -> JMethodID -> [JValue] -> IO ()
callVoidMethod (JNIEnv_ env) obj method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| void {
      (*$(JNIEnv *env))->CallVoidMethodA($(JNIEnv *env),
                                         $(jobject obj),
                                         $(jmethodID method),
                                         $(jvalue *cargs)) } |]

callStaticObjectMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO JObject
callStaticObjectMethod (JNIEnv_ env) cls method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| jobject {
      (*$(JNIEnv *env))->CallStaticObjectMethodA($(JNIEnv *env),
                                                 $(jobject cls),
                                                 $(jmethodID method),
                                                 $(jvalue *cargs)) } |]

callStaticVoidMethod :: JNIEnv -> JClass -> JMethodID -> [JValue] -> IO ()
callStaticVoidMethod (JNIEnv_ env) cls method args =
    throwIfException env $
    withArray args $ \cargs ->
    [C.exp| void {
      (*$(JNIEnv *env))->CallStaticVoidMethodA($(JNIEnv *env),
                                               $(jobject cls),
                                               $(jmethodID method),
                                               $(jvalue *cargs)) } |]

newIntArray :: JNIEnv -> Int32 -> IO JIntArray
newIntArray (JNIEnv_ env) sz =
    throwIfException env $
    [CU.exp| jintArray {
      (*$(JNIEnv *env))->NewIntArray($(JNIEnv *env),
                                     $(jsize sz)) } |]

newByteArray :: JNIEnv -> Int32 -> IO JByteArray
newByteArray (JNIEnv_ env) sz =
    throwIfException env $
    [CU.exp| jbyteArray {
      (*$(JNIEnv *env))->NewByteArray($(JNIEnv *env),
                                      $(jsize sz)) } |]

newDoubleArray :: JNIEnv -> Int32 -> IO JDoubleArray
newDoubleArray (JNIEnv_ env) sz =
    throwIfException env $
    [CU.exp| jdoubleArray {
      (*$(JNIEnv *env))->NewDoubleArray($(JNIEnv *env),
                                        $(jsize sz)) } |]

newObjectArray :: JNIEnv -> Int32 -> JClass -> IO JObjectArray
newObjectArray (JNIEnv_ env) sz cls =
    throwIfException env $
    [CU.exp| jobjectArray {
      (*$(JNIEnv *env))->NewObjectArray($(JNIEnv *env),
                                        $(jsize sz),
                                        $(jclass cls),
                                        NULL) } |]

newStringUTF :: JNIEnv -> String -> IO JString
newStringUTF (JNIEnv_ env) str =
    throwIfException env $
    withCString str $ \cstr ->
    [CU.exp| jstring {
      (*$(JNIEnv *env))->NewStringUTF($(JNIEnv *env),
                                      $(char *cstr)) } |]

getArrayLength :: JNIEnv -> JArray -> IO Int32
getArrayLength (JNIEnv_ env) array =
    [C.exp| jsize {
      (*$(JNIEnv *env))->GetArrayLength($(JNIEnv *env),
                                        $(jarray array)) } |]
getStringUTFLength :: JNIEnv -> JString -> IO Int32
getStringUTFLength (JNIEnv_ env) jstr =
    throwIfException env $
    [CU.exp| jsize {
      (*$(JNIEnv *env))->GetStringUTFLength($(JNIEnv *env),
                                            $(jstring jstr)) } |]

getIntArrayElements :: JNIEnv -> JIntArray -> IO (Ptr Int32)
getIntArrayElements (JNIEnv_ env) array =
    [CU.exp| jint* {
      (*$(JNIEnv *env))->GetIntArrayElements($(JNIEnv *env),
                                             $(jintArray array),
                                             NULL) } |]

getByteArrayElements :: JNIEnv -> JByteArray -> IO (Ptr CChar)
getByteArrayElements (JNIEnv_ env) array =
    [CU.exp| jbyte* {
      (*$(JNIEnv *env))->GetByteArrayElements($(JNIEnv *env),
                                              $(jbyteArray array),
                                              NULL) } |]

getDoubleArrayElements :: JNIEnv -> JDoubleArray -> IO (Ptr Double)
getDoubleArrayElements (JNIEnv_ env) array =
    [CU.exp| jdouble* {
      (*$(JNIEnv *env))->GetDoubleArrayElements($(JNIEnv *env),
                                                $(jdoubleArray array),
                                                NULL) } |]

getStringUTFChars :: JNIEnv -> JString -> IO (Ptr CChar)
getStringUTFChars (JNIEnv_ env) jstr =
    throwIfException env $
    [CU.exp| const char* {
      (*$(JNIEnv *env))->GetStringUTFChars($(JNIEnv *env),
                                           $(jstring jstr),
                                           NULL) } |]

setIntArrayRegion :: JNIEnv -> JIntArray -> Int32 -> Int32 -> Ptr Int32 -> IO ()
setIntArrayRegion (JNIEnv_ env) array start len buf =
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetIntArrayRegion($(JNIEnv *env),
                                            $(jintArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jint *buf)) } |]

setByteArrayRegion :: JNIEnv -> JByteArray -> Int32 -> Int32 -> Ptr CChar -> IO ()
setByteArrayRegion (JNIEnv_ env) array start len buf =
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetByteArrayRegion($(JNIEnv *env),
                                            $(jbyteArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jbyte *buf)) } |]

setDoubleArrayRegion :: JNIEnv -> JDoubleArray -> Int32 -> Int32 -> Ptr Double -> IO ()
setDoubleArrayRegion (JNIEnv_ env) array start len buf =
    throwIfException env $
    [CU.exp| void {
      (*$(JNIEnv *env))->SetDoubleArrayRegion($(JNIEnv *env),
                                            $(jdoubleArray array),
                                            $(jsize start),
                                            $(jsize len),
                                            $(jdouble *buf)) } |]

releaseStringUTFChars :: JNIEnv -> JString -> Ptr CChar -> IO ()
releaseStringUTFChars (JNIEnv_ env) jstr chars =
    [CU.exp| void {
      (*$(JNIEnv *env))->ReleaseStringUTFChars($(JNIEnv *env),
                                               $(jstring jstr),
                                               $(char *chars)) } |]
