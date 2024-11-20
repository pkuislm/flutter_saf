#define FFIEXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#include <jni.h>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <pthread.h>
#include <android/log.h>
#include <sys/stat.h>

static struct {
    JavaVM * _vm;

    jclass _cls;
    jobject _clsInst;

    jmethodID openDir;
    jmethodID getParent;
    jmethodID listDir;
    jmethodID createDir;
    jmethodID renameDir;
    jmethodID checkDescriptor;
    jmethodID deleteDir;
    jmethodID openFile;
    jmethodID getFileSize;
    jmethodID createFile;
    jmethodID renameFile;
    jmethodID deleteFile;

    jclass intClass;
    jmethodID int_intValue;
    jmethodID int_valueOf;

    jclass arrayListClass;
    jmethodID arraylist_get;
    jmethodID arraylist_size;

    jclass pairClass;
    jfieldID pair_first;
    jfieldID pair_second;
}s_instance{};

static const char* fileModes[] = {"r", "rwt", "wa", "wt", "wa"};

static pthread_key_t tsd_key{};

void destructor_function(void *data) {
    __android_log_print(ANDROID_LOG_DEBUG, "PathWrapper", "Detach javavm executed");
    s_instance._vm->DetachCurrentThread();
}

FFIEXPORT
void* _malloc(int32_t size) {
    return malloc(size);
}

FFIEXPORT
void _free(void* ptr) {
    free(ptr);
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    s_instance._vm = vm;
    pthread_key_create(&tsd_key, destructor_function);
    return JNI_VERSION_1_6;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM* vm, void* reserved)
{
    __android_log_print(ANDROID_LOG_DEBUG, "PathWrapper", "JNI_OnUnLoad");
}

//Flutter <-> cpp <-> kotlin
extern "C" JNIEXPORT void JNICALL
Java_org_pkuism_flutter_1saf_SAFPathWrapper_setupNativeProxy(JNIEnv* env, jobject instance) {
    s_instance._clsInst = env->NewGlobalRef(instance);

    jclass cls = env->GetObjectClass(instance);
    s_instance._cls = (jclass)env->NewGlobalRef(cls);
    s_instance.openDir = env->GetMethodID(cls, "onOpenPath", "(Ljava/lang/String;)Landroid/util/Pair;");
    s_instance.getParent = env->GetMethodID(cls, "getParent", "(I)I");
    s_instance.listDir = env->GetMethodID(cls, "listDirectory", "(I)Landroid/util/Pair;");
    s_instance.createDir = env->GetMethodID(cls, "createDirectory", "(Ljava/lang/String;Z)Landroid/util/Pair;");
    s_instance.checkDescriptor = env->GetMethodID(cls, "checkDocumentStat", "(I)I");
    s_instance.deleteDir = env->GetMethodID(cls, "deleteDir", "(IZ)I");
    s_instance.renameDir = env->GetMethodID(cls, "renameDirectory", "(ILjava/lang/String;)Landroid/util/Pair;");
    s_instance.openFile = env->GetMethodID(cls, "fopen", "(ILjava/lang/String;)I");
    s_instance.getFileSize = env->GetMethodID(cls, "getFileSize", "(I)I");
    s_instance.createFile = env->GetMethodID(cls, "createDirectory", "(Ljava/lang/String;ZZ)Landroid/util/Pair;");
    s_instance.renameFile = env->GetMethodID(cls, "renameFile", "(ILjava/lang/String;Z)Landroid/util/Pair;");
    s_instance.deleteFile = env->GetMethodID(cls, "deleteFile", "(I)I");

    jclass intClass = env->FindClass("java/lang/Integer");
    s_instance.intClass = (jclass)env->NewGlobalRef(intClass);
    s_instance.int_intValue = env->GetMethodID(intClass, "intValue", "()I");
    s_instance.int_valueOf = env->GetStaticMethodID(intClass, "valueOf", "(I)Ljava/lang/Integer;");

    jclass arrayListClass = env->FindClass("java/util/ArrayList");
    s_instance.arrayListClass = (jclass)env->NewGlobalRef(arrayListClass);
    s_instance.arraylist_get = env->GetMethodID(arrayListClass, "get", "(I)Ljava/lang/Object;");
    s_instance.arraylist_size = env->GetMethodID(arrayListClass, "size", "()I");

    jclass pairClass = env->FindClass("android/util/Pair");
    s_instance.pairClass = (jclass)env->NewGlobalRef(pairClass);
    s_instance.pair_first = env->GetFieldID(pairClass, "first", "Ljava/lang/Object;");
    s_instance.pair_second = env->GetFieldID(pairClass, "second", "Ljava/lang/Object;");
}

extern "C" JNIEXPORT void JNICALL
Java_org_pkuism_flutter_1saf_SAFPathWrapper_destroyNativeProxy(JNIEnv* env, jobject instance) {
    env->DeleteGlobalRef(s_instance._clsInst);
    env->DeleteGlobalRef(s_instance._cls);
    env->DeleteGlobalRef(s_instance.intClass);
    env->DeleteGlobalRef(s_instance.arrayListClass);
    env->DeleteGlobalRef(s_instance.pairClass);
}

FFIEXPORT
int32_t checkDescriptor(int32_t descriptor) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    int32_t ret = env->CallIntMethod(s_instance._clsInst, s_instance.checkDescriptor, (jint)descriptor);
    return ret;
}

struct DirContent {
    int8_t** folders;
    int32_t folder_count;
    int8_t** files;
    int32_t file_count;
};
FFIEXPORT
DirContent* listDir(uint32_t descriptor) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    DirContent* dirInfo = nullptr;
    jobject pairRet = env->CallObjectMethod(s_instance._clsInst, s_instance.listDir, (jint)descriptor);
    jobject ret = env->GetObjectField(pairRet, s_instance.pair_second);

    dirInfo = (DirContent*)malloc(sizeof(DirContent));
    jobject folders = env->CallObjectMethod(ret, s_instance.arraylist_get, 0);
    jobject files = env->CallObjectMethod(ret, s_instance.arraylist_get, 1);

    auto folderCount= env->CallIntMethod(folders, s_instance.arraylist_size);
    if(folderCount > 0) {
        dirInfo->folders = (int8_t**)malloc(folderCount * sizeof(int8_t*));
        for(int i = 0; i < folderCount; i++) {
            auto path = (jstring)env->CallObjectMethod(folders, s_instance.arraylist_get, i);
            auto s = env->GetStringUTFChars(path, nullptr);
            dirInfo->folders[i] = (int8_t*)strdup(s);
            env->ReleaseStringUTFChars(path, s);
        }
    }
    dirInfo->folder_count = folderCount;

    auto fileCount = env->CallIntMethod(files, s_instance.arraylist_size);
    if(fileCount > 0) {
        dirInfo->files = (int8_t**)malloc(fileCount * sizeof(int8_t*));
        for(int i = 0; i < fileCount; i++) {
            auto path = (jstring)env->CallObjectMethod(files, s_instance.arraylist_get, i);
            auto s = env->GetStringUTFChars(path, nullptr);
            dirInfo->files[i] = (int8_t*)strdup(s);
            env->ReleaseStringUTFChars(path, s);
        }
    }
    dirInfo->file_count = fileCount;
    return dirInfo;
}

struct DirInfo {
    int8_t* path;
    int32_t descriptor;
};
FFIEXPORT
DirInfo* openDir(int8_t* path) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    DirInfo* dirInfo = nullptr;
    jstring open_path = env->NewStringUTF((char*)path);
    jobject ret = env->CallObjectMethod(s_instance._clsInst, s_instance.openDir, open_path);
    if(ret != nullptr) {
        dirInfo = (DirInfo*)malloc(sizeof(DirInfo));
        auto parsed_path = (jstring)env->GetObjectField(ret, s_instance.pair_first);
        auto s = env->GetStringUTFChars(parsed_path, nullptr);

        dirInfo->path = (int8_t*)strdup(s);
        env->ReleaseStringUTFChars(parsed_path, s);
        jobject c = env->GetObjectField(ret, s_instance.pair_second);
        dirInfo->descriptor = env->CallIntMethod(c, s_instance.int_intValue);
    }
    return dirInfo;
}

FFIEXPORT
int32_t getParent(int32_t descriptor) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    return env->CallIntMethod(s_instance._clsInst, s_instance.getParent, descriptor);
}

FFIEXPORT
DirInfo* createDir(int8_t* path, bool recursive) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    auto* dirInfo = (DirInfo*)malloc(sizeof(DirInfo));
    jstring create_path = env->NewStringUTF((char*)path);

    jobject ret = env->CallObjectMethod(s_instance._clsInst, s_instance.createDir, create_path, recursive);
    auto parsed_path = (jstring)env->GetObjectField(ret, s_instance.pair_first);
    auto s = env->GetStringUTFChars(parsed_path, nullptr);

    dirInfo->path = (int8_t*)strdup(s);
    env->ReleaseStringUTFChars(parsed_path, s);
    jobject c = env->GetObjectField(ret, s_instance.pair_second);
    dirInfo->descriptor = env->CallIntMethod(c, s_instance.int_intValue);
    return dirInfo;
}

FFIEXPORT
DirInfo* renameDir(int32_t descriptor, int8_t* newPath) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    auto* dirInfo = (DirInfo*)malloc(sizeof(DirInfo));
    jstring n = env->NewStringUTF((char*)newPath);

    jobject ret = env->CallObjectMethod(s_instance._clsInst, s_instance.renameDir, descriptor, n);
    auto new_name = (jstring)env->GetObjectField(ret, s_instance.pair_first);
    auto s = env->GetStringUTFChars(new_name, nullptr);

    dirInfo->path = (int8_t*)strdup(s);
    env->ReleaseStringUTFChars(new_name, s);
    jobject c = env->GetObjectField(ret, s_instance.pair_second);
    dirInfo->descriptor = env->CallIntMethod(c, s_instance.int_intValue);
    return dirInfo;
}

FFIEXPORT
int32_t deleteDir(int32_t descriptor, bool recursive) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    int32_t result = env->CallIntMethod(s_instance._clsInst, s_instance.deleteDir, descriptor, recursive);
    return result;
}

FFIEXPORT
DirInfo* createFile(int8_t* path, bool recursive) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    auto* dirInfo = (DirInfo*)malloc(sizeof(DirInfo));
    jstring create_path = env->NewStringUTF((char*)path);

    jobject ret = env->CallObjectMethod(s_instance._clsInst, s_instance.createFile, create_path, recursive, true);
    auto parsed_path = (jstring)env->GetObjectField(ret, s_instance.pair_first);
    auto s = env->GetStringUTFChars(parsed_path, nullptr);

    dirInfo->path = (int8_t*)strdup(s);
    env->ReleaseStringUTFChars(parsed_path, s);
    jobject c = env->GetObjectField(ret, s_instance.pair_second);
    dirInfo->descriptor = env->CallIntMethod(c, s_instance.int_intValue);
    return dirInfo;
}

FFIEXPORT
DirInfo* renameFile(int32_t descriptor, int8_t* newPath, bool copy) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    auto* dirInfo = (DirInfo*)malloc(sizeof(DirInfo));
    jstring n = env->NewStringUTF((char*)newPath);

    jobject ret = env->CallObjectMethod(s_instance._clsInst, s_instance.renameFile, descriptor, n, copy);
    auto new_name = (jstring)env->GetObjectField(ret, s_instance.pair_first);
    auto s = env->GetStringUTFChars(new_name, nullptr);

    dirInfo->path = (int8_t*)strdup(s);
    env->ReleaseStringUTFChars(new_name, s);
    jobject c = env->GetObjectField(ret, s_instance.pair_second);
    dirInfo->descriptor = env->CallIntMethod(c, s_instance.int_intValue);
    return dirInfo;
}

FFIEXPORT
int32_t deleteFile(int32_t descriptor) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    int32_t result = env->CallIntMethod(s_instance._clsInst, s_instance.deleteFile, descriptor);
    return result;
}

FFIEXPORT
int32_t getFileSize(int32_t descriptor) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);

    int32_t result = env->CallIntMethod(s_instance._clsInst, s_instance.getFileSize, descriptor);
    return result;
}

//get a error code or fd
FFIEXPORT
int32_t _fopen(int32_t descriptor, int32_t mode) {
    JNIEnv* env;
    s_instance._vm->AttachCurrentThread(&env, nullptr);
    jstring m = env->NewStringUTF(fileModes[mode]);

    return env->CallIntMethod(s_instance._clsInst, s_instance.openFile, descriptor, m);
}

//thread unaware, since fd is share across the process
FFIEXPORT
int32_t _fclose(int32_t fd) {
    return close(fd);
}

FFIEXPORT
int32_t _fread(int32_t fd, int8_t* buf, int32_t count) {
    return read(fd, buf, count);
}

FFIEXPORT
int32_t  _freadByte(int32_t fd) {
    int8_t b = 0;
    auto count = read(fd, &b, 1);
    return count == 1 ? b : -1;
}

FFIEXPORT
int32_t _fwrite(int32_t fd, int8_t* buf, int32_t count) {
    return write(fd, buf, count);
}

FFIEXPORT
int32_t _fwriteByte(int32_t fd, int32_t buf) {
    return write(fd, &buf, 1);
}

FFIEXPORT
int32_t _ftell(int32_t fd) {
    return lseek(fd, 0, SEEK_CUR);
}

FFIEXPORT
int32_t _fseek(int32_t fd, int32_t offset) {
    return lseek(fd, offset, SEEK_SET);
}

FFIEXPORT
int32_t _fflush(int32_t fd) {
    return fdatasync(fd);
}

FFIEXPORT
int32_t _fsize(int32_t fd) {
    struct stat s{};
    auto ret = fstat(fd, &s);
    return ret < 0 ? ret : s.st_size;
}

struct FileContent {
    int8_t * data;
    int32_t size;
};
FFIEXPORT
FileContent* fileReadAllBytes(int32_t descriptor) {
    auto file = _fopen(descriptor, 0);
    auto size = _fsize(file);
    auto ret = (FileContent*)malloc(sizeof(FileContent));
    ret->data = (int8_t*)malloc(size);

    ret->size = _fread(file, ret->data, size);
    _fclose(file);
    return ret;
}

FFIEXPORT
int32_t fileWriteAllBytes(int32_t descriptor, int8_t* data, int32_t sizeOfData, int32_t mode) {
    auto file = _fopen(descriptor, mode);

    auto size = _fwrite(file, data, sizeOfData);

    _fclose(file);
    return size;
}