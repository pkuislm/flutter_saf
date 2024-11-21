package org.pkuism.flutter_saf

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Pair
import androidx.annotation.Keep
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File


/** FlutterSafPlugin */
class FlutterSafPlugin: FlutterPlugin, MethodCallHandler, PluginRegistry.ActivityResultListener, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var fileMgr : SAFPathWrapper
  private lateinit var result: Result
  private lateinit var myActivity: Activity

  private val CODE_AUTHORIZE_NEW_DIR = 0x8000

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    fileMgr = SAFPathWrapper(flutterPluginBinding.applicationContext)
    fileMgr.init()
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_saf")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, res: Result) {
    result = res
    when (call.method) {
      "pick" -> {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
          Intent.FLAG_GRANT_READ_URI_PERMISSION
                  or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                  or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        myActivity.startActivityForResult(intent, CODE_AUTHORIZE_NEW_DIR)
      }
      "open" -> {
        val path = call.argument<String>("p")
        if (path != null) {
          val dirInfo = fileMgr.onOpenPath(path)
          val result = ArrayList<Any>()

          result.add(dirInfo.first)
          result.add(dirInfo.second)
          res.success(result)
        } else {
          res.success(null)
        }
      }
      "list" -> {
        val descriptor = call.argument<Int>("d")
        if(descriptor != null) {
          val root = fileMgr.listDirectory(descriptor)
          res.success(root.second)
        } else {
          res.success(null)
        }
      }
      "parent" -> {
        val descriptor = call.argument<Int>("d")
        if(descriptor != null) {
          res.success(fileMgr.getParent(descriptor))
        } else {
          res.success(null)
        }
      }
      "validate" -> {
        val d = call.argument<Int>("d")
        if(d != null) {
          res.success(fileMgr.checkDocumentStat(d))
        } else {
          res.success(-1)
        }
      }
      "createDir" ->{
        val p = call.argument<String>("p")
        val r = call.argument<Boolean>("r")
        if (p != null && r != null) {
          val dirInfo = fileMgr.createDirectory(p, r)
          if(dirInfo.second < 0) {
            res.success(null)
          } else {
            val result = ArrayList<Any>()
            result.add(dirInfo.first)
            result.add(dirInfo.second)
            res.success(result)
          }
        } else {
          res.success(null)
        }
      }
      "delete" -> {
        val d = call.argument<Int>("d")
        val r = call.argument<Boolean>("r")
        if (d != null && r != null) {
          res.success(fileMgr.deleteDir(d, r))
        } else {
          res.success(null)
        }
      }
      "rename" -> {
        val d = call.argument<Int>("d")
        val n = call.argument<String>("n")
        if (d != null && n != null) {
          val dirInfo = fileMgr.renameDirectory(d, n)
          if (dirInfo.second <= 0) {
            res.success(null)
          } else {
            val result = ArrayList<Any>()
            result.add(dirInfo.first)
            result.add(dirInfo.second)
            res.success(result)
          }
        } else {
          res.success(null)
        }
      }
      "fsize" -> {
        val d = call.argument<Int>("d")
        if (d != null) {
          res.success(fileMgr.getFileSize(d))
        } else {
          res.success(0)
        }
      }
      "rt" -> {
        val d = call.argument<Int>("d")
        val n = call.argument<String>("n")
        fileMgr.test(d!!, n!!)
        res.success(null)
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    fileMgr.shutdown()
    channel.setMethodCallHandler(null)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if(requestCode == CODE_AUTHORIZE_NEW_DIR) {
      result.success(fileMgr.handleIntentResult(resultCode, data))
      return true
    }
    return false
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    myActivity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    myActivity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() { }
  override fun onDetachedFromActivityForConfigChanges() { }
}

class LRUCache<K, V>(private val maxCapacity: Int) :
  LinkedHashMap<K, V>(maxCapacity, 0.75f, true)
{
  override fun removeEldestEntry(eldest: Map.Entry<K, V>): Boolean {
    return super.size > maxCapacity
  }
}

@Keep
class SAFPathWrapper(private val myContext: Context) {
  //HashCode of getUri()
  private val _roots: HashMap<String, Uri> = HashMap()
  //HashCode of DocumentFile
  private val _handles: LRUCache<Int, DocumentFile> = LRUCache(5000)

  private fun getRootUri(rootId: String): Uri? {
    return _roots.getOrDefault(rootId, null)
  }

  private fun getRootUriByName(path: String): Pair<Int, Uri>? {
    for (k in _roots.keys) {
      val pos = path.indexOf(k)
      if (pos != -1) {
        return Pair(pos, _roots[k])
      }
    }
    return null
  }

  //document descriptor:
  //>0: normal documentfile
  // 0: root document
  //-1:invalid document
  //-2:document cache invalid(need refresh your descriptor)
  //-3 this file is accessible through direct path
  enum class SpecialDescriptors(val id: Int) {
    DOC_ROOT(0), DOC_INVALID(-1), DOC_CACHE_MISS(-2), DOC_NORMAL(-3)
  }

  private fun getDocument(descriptor: Int): DocumentFile? {
    return _handles.getOrDefault(descriptor, null)
  }

  private fun setDocument(doc: DocumentFile):Int {
    val descriptor = doc.hashCode().and(Int.MAX_VALUE)//ensure value is positive
    _handles[descriptor] = doc
    return descriptor
  }

  fun checkDocumentStat(descriptor: Int): Int {
    if(descriptor <= 0)
      return descriptor
    if(!_handles.containsKey(descriptor))
      return SpecialDescriptors.DOC_CACHE_MISS.id
    val doc = _handles[descriptor]
    //object exists, but this file is gone
    if(!doc!!.exists()) {
      _handles.remove(descriptor)
      return SpecialDescriptors.DOC_CACHE_MISS.id
    }
    return descriptor
  }

  private external fun setupNativeProxy()
  private external fun destroyNativeProxy()

  fun init() {
    System.loadLibrary("flutter-saf")
    setupNativeProxy()
    val permissions = myContext.contentResolver.persistedUriPermissions
    for (p in permissions) {
      updateRoot(p.uri)
    }
  }

  fun shutdown() {
    _handles.clear()
    _roots.clear()
    destroyNativeProxy()
  }

  fun listRoots(): ArrayList<ArrayList<String>> {
    val ret = ArrayList<ArrayList<String>>();
    val dirs = ArrayList<String>();
    val uris = ArrayList<String>();

    for (k in _roots.keys) {
      dirs.add(k)
      uris.add(_roots[k]?.path ?: k)
    }
    ret.add(dirs)
    ret.add(uris)
    return ret
  }

  fun removeRootUri(path: String) {
    val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    myContext.contentResolver.releasePersistableUriPermission(_roots[path]!!, takeFlags)
  }

  fun handleIntentResult(resultCode: Int, data: Intent?):ArrayList<String>? {
    if(resultCode != RESULT_OK) {
      return null
    }
    val pickedDirectoryUri = data?.data ?: return null

    myContext.contentResolver.takePersistableUriPermission(pickedDirectoryUri,
      Intent.FLAG_GRANT_READ_URI_PERMISSION
              or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

    val rootID = updateRoot(pickedDirectoryUri)

    val root = "/$rootID"
    val info = ArrayList<String>()
    info.add(root)
    info.add(onOpenPath(root).second.toString())

    return info
  }

  private fun updateRoot(uri: Uri): String {
    val id = DocumentsContract.getTreeDocumentId(uri)
    _roots[id] = uri
    return id
  }

  //Handle
  //Path is like /primary:comic/bar/foo/text.png
  //             | treedoc.id |  normalPath
  //root directory's descriptor will be nothing
  //Cache DocumentFile to gain better performance
  //both dir and file uses this function
  fun onOpenPath(p: String): Pair<String, Int> {
    val path = if(p.startsWith("file://", ignoreCase = true)) p.substring(7) else p;

    if(path == "/") {
      return Pair("", SpecialDescriptors.DOC_ROOT.id)
    }

    try {
      val rootInfo = getRootUriByName(path) ?: return Pair(path, SpecialDescriptors.DOC_NORMAL.id)

      val fileID = path.substring(rootInfo.first).trimStart('/')
      val target = DocumentFile.fromTreeUri(
        myContext,
        DocumentsContract.buildDocumentUriUsingTree(rootInfo.second, fileID)
      )

      if (target != null) {
        if(target.exists()) {
          return Pair(path, setDocument(target))
        }
        return Pair(path, SpecialDescriptors.DOC_INVALID.id)
      }
      return Pair("", SpecialDescriptors.DOC_INVALID.id)

    } catch (e1: Exception) {
      return Pair("", SpecialDescriptors.DOC_INVALID.id)
    }
  }

  fun getParent(descriptor: Int): Int {
    if(descriptor > 0) {
      val df = getDocument(descriptor) ?: return SpecialDescriptors.DOC_CACHE_MISS.id
      val pf = df.parentFile ?: return SpecialDescriptors.DOC_ROOT.id//root
      return setDocument(pf)
    }
    return SpecialDescriptors.DOC_INVALID.id
  }

  @JvmOverloads
  fun createDirectory(path: String, recursive: Boolean, isFile: Boolean = false, type: String = "application/octet-stream"): Pair<String, Int> {
    //root directory can't create new directory
    if (path == "/" || path.isEmpty()) {
      return Pair("", SpecialDescriptors.DOC_INVALID.id)
    }

    val rootInfo = getRootUriByName(path) ?: return Pair(path, SpecialDescriptors.DOC_NORMAL.id)

    val fID = path.substring(rootInfo.first).trimStart('/')

    var father =
      DocumentFile.fromTreeUri(
        myContext,
        DocumentsContract.buildDocumentUriUsingTree(rootInfo.second, fID)
      )
        ?: return Pair("", SpecialDescriptors.DOC_INVALID.id)

    if(!father.exists()) {
      if(!recursive) {
        return Pair("", SpecialDescriptors.DOC_INVALID.id)
      }
      val paths = fID.split("/")
      for(p in paths) {
        if(p.isEmpty()) {
          continue
        }
        father = father.createDirectory(p)!!
      }
    }

    val rID = path.substring(path.lastIndexOf("/") + 1)
    if(isFile) {
      father = father.createFile(type, rID)!!
    } else {
      father = father.createDirectory(rID)!!
    }
    return Pair(path, setDocument(father))
  }

  fun listDirectory(descriptor: Int): Pair<Int, ArrayList<ArrayList<String>>> {
    if(descriptor == SpecialDescriptors.DOC_ROOT.id) {
      //root directory, list all authorized directories
      val dirList = ArrayList<String>()
      val fileList = ArrayList<String>()
      for(r in _roots.keys) {
        dirList.add(r)
      }
      val dirInfo = ArrayList<ArrayList<String>>()
      dirInfo.add(dirList)
      dirInfo.add(fileList)
      return Pair(SpecialDescriptors.DOC_ROOT.id, dirInfo)
    }

    val dirInfo = ArrayList<ArrayList<String>>()
    if(descriptor < 0) {
      return Pair(descriptor, dirInfo)
    }
    try {
      val root = getDocument(descriptor)
      if (root != null) {
        //certainly
        if(root.isDirectory) {
          val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(root.uri, DocumentsContract.getDocumentId(root.uri))
          val c: Cursor? = myContext.contentResolver.query(childrenUri,
            arrayOf<String>(
              DocumentsContract.Document.COLUMN_DISPLAY_NAME,
              DocumentsContract.Document.COLUMN_MIME_TYPE,
              //DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            ),
            null,
            null,
            null
          )

          val dirList = ArrayList<String>()
          val fileList = ArrayList<String>()
          c.use { q ->
            if (q != null) {
              while (q.moveToNext()) {
                val name = q.getString(0)
                val mime = q.getString(1)
                //val docId = q.getString(2)
                if(mime.equals(DocumentsContract.Document.MIME_TYPE_DIR)) {
                  dirList.add(name)
                } else {
                  fileList.add(name)
                }
              }
            }
          }
          dirInfo.add(dirList)
          dirInfo.add(fileList)
          return Pair(descriptor, dirInfo)
        }
      }
      return Pair(SpecialDescriptors.DOC_CACHE_MISS.id, dirInfo)
    } catch (e: SecurityException) {
      return Pair(SpecialDescriptors.DOC_INVALID.id, dirInfo)
    }
  }

  //0: root dir(currently can't copy)
  //-1:invalid source dir
  //-2 cache miss
  //-3 dest is a file
  //-4 dest is not an empty folder
  //-5
  fun renameDirectory(descriptor: Int, newPath: String): Pair<String, Int> {
    if(descriptor <= 0) {
      return Pair("", descriptor)
    }

    val src = getDocument(descriptor) ?: return Pair("", -2)
    var dstInfo = onOpenPath(newPath)
    val dstFile: DocumentFile
    if(dstInfo.second == SpecialDescriptors.DOC_NORMAL.id) {

      dstFile = DocumentFile.fromFile(File(newPath))

    } else if(dstInfo.second == SpecialDescriptors.DOC_INVALID.id) {

      dstInfo = createDirectory(newPath, true)
      dstFile = getDocument(dstInfo.second)!!

    } else {
      dstFile = getDocument(dstInfo.second)!!
      if(dstFile.isFile) {
        return Pair("", -3)
      }
      if(dstFile.isDirectory && dstFile.listFiles().isNotEmpty()) {
        return Pair("", -4)
      }
    }

    //no error
    var flag = true

    fun copyDir(src: DocumentFile, dst: DocumentFile) {
      for(sf in src.listFiles()) {
        if(sf.isFile) {
          val sft = if(sf.type == null) "application/octet-stream" else sf.type!!
          val df = dst.createFile(sft, sf.name!!)
          val sfs = myContext.contentResolver.openInputStream(sf.uri)!!
          val dfs = myContext.contentResolver.openOutputStream(df!!.uri)!!
          sfs.copyTo(dfs)
          dfs.close()
          sfs.close()
        } else {
          val dd = dst.createDirectory(sf.name!!)!!
          copyDir(sf, dd)
        }
      }
    }

    try {
        copyDir(src, dstFile)
    } catch (e : Exception) {
      flag = false
    }

    if(flag) {
      src.delete()
      return Pair(dstInfo.first, dstInfo.second)
    } else {
      dstFile.delete()
      return Pair("", -5)
    }
  }

  fun renameFile(descriptor: Int, newPath: String, copy: Boolean): Pair<String, Int> {
    if(descriptor <= 0) {
      return Pair("", descriptor)
    }

    val src = getDocument(descriptor) ?: return Pair("", -2)
    var dstInfo = onOpenPath(newPath)
    val dstFile: DocumentFile
    if(dstInfo.second == SpecialDescriptors.DOC_NORMAL.id) {
      dstFile = DocumentFile.fromFile(File(newPath))
    } else if(dstInfo.second == SpecialDescriptors.DOC_INVALID.id) {
      dstInfo = createDirectory(newPath, recursive = true, isFile = true, type = src.type ?: "application/octet-stream")
      dstFile = getDocument(dstInfo.second)!!
    } else {
      dstFile = getDocument(dstInfo.second)!!
      if(!dstFile.isFile) {
        return Pair("", -3)
      }
    }

    //no error
    var flag = true

    try {
      val sfs = myContext.contentResolver.openInputStream(src.uri)!!
      val dfs = myContext.contentResolver.openOutputStream(dstFile.uri)!!
      sfs.copyTo(dfs)
      sfs.close()
      dfs.close()
    } catch (e : Exception) {
      flag = false
    }

    if(flag) {
      if(!copy) {
        src.delete();
      }
      return Pair(dstInfo.first, dstInfo.second)
    } else {
      dstFile.delete();
      return Pair("", -5)
    }
  }

  //return: status
  fun deleteDir(descriptor: Int, recursive: Boolean): Int {
    if(descriptor <= 0) {
      //cannot delete root or invalid folder
      return -1
    }
    val root = getDocument(descriptor) ?: return -2

    val content = root.listFiles()
    if(content.isNotEmpty()) {
      if(!recursive) {
        //directory is not empty but recursive is false
        return -3
      }
      return if(!root.delete()) -1 else 0
    }
    return if(!root.delete()) -1 else 0
  }

  fun deleteFile(descriptor: Int): Int {
    if(descriptor <= 0) {
      //cannot delete root or invalid folder
      return -1
    }
    val root = getDocument(descriptor) ?: return -2
    return if(!root.delete()) -1 else 0
  }

  fun test(d: Int, n: String) {
    val doc = getDocument(d)!!
    doc.renameTo(n)
  }

  fun getFileSize(descriptor: Int): Int {
    if(descriptor <= 0) {
      return 0
    }
    val doc = getDocument(descriptor) ?: return 0
    return if(doc.isFile) doc.length().toInt() else 0
  }

  //returning a descriptor to cpp or an error code
  //-1 file not exist
  //-2 permission denied
  //-3 unknown error
  fun fopen(descriptor: Int, mode: String): Int {
    if(descriptor <= 0) {
      return -1
    }
    val doc = getDocument(descriptor) ?: return -1
    return try {
      val pfd = myContext.contentResolver.openFileDescriptor(doc.uri, mode)
      pfd?.detachFd() ?: -2
    } catch (e: Exception) {
      -2
    }
  }
}
