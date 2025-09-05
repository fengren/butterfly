package com.example.butterfly

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import android.content.ContentResolver
import android.net.Uri
import java.util.UUID
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.example.butterfly/share_intent"
    }
    
    private lateinit var methodChannel: MethodChannel
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        Log.d(TAG, "MethodChannel configured")
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate called")
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "MainActivity onNewIntent called")
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "Intent is null")
            return
        }
        
        Log.d(TAG, "Handling intent: action=${intent.action}, type=${intent.type}")
        
        val shareData = mutableMapOf<String, Any?>()
        
        // 获取调用应用的包名
        val callingPackage = getCallingPackage(intent)
        shareData["sourceApp"] = callingPackage
        Log.d(TAG, "Calling package: $callingPackage")
        
        when (intent.action) {
            Intent.ACTION_SEND -> {
                Log.d(TAG, "Received ACTION_SEND intent")
                
                // 提取文本内容
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (sharedText != null) {
                    shareData["text"] = sharedText
                    Log.d(TAG, "Extracted text: $sharedText")
                }
                
                // 提取单个文件/图片
                val streamUri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                if (streamUri != null) {
                    val processedPath = processFileUri(streamUri)
                    if (processedPath != null) {
                        shareData["files"] = listOf(processedPath)
                        Log.d(TAG, "Extracted and processed single file: $processedPath")
                    } else {
                        Log.w(TAG, "Failed to process file URI: $streamUri")
                    }
                }
                
                shareData["type"] = intent.type ?: "unknown"
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                Log.d(TAG, "Received ACTION_SEND_MULTIPLE intent")
                
                // 提取文本内容
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (sharedText != null) {
                    shareData["text"] = sharedText
                    Log.d(TAG, "Extracted text: $sharedText")
                }
                
                // 提取多个文件
                val streamUris = intent.getParcelableArrayListExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                if (streamUris != null && streamUris.isNotEmpty()) {
                    val processedPaths = mutableListOf<String>()
                    for (uri in streamUris) {
                        val processedPath = processFileUri(uri)
                        if (processedPath != null) {
                            processedPaths.add(processedPath)
                        } else {
                            Log.w(TAG, "Failed to process file URI: $uri")
                        }
                    }
                    if (processedPaths.isNotEmpty()) {
                        shareData["files"] = processedPaths
                        Log.d(TAG, "Extracted and processed multiple files: $processedPaths")
                    }
                }
                
                shareData["type"] = intent.type ?: "unknown"
            }
            else -> {
                Log.d(TAG, "Unhandled intent action: ${intent.action}")
                return
            }
        }
        
        // 发送数据到Flutter层
        if (shareData.isNotEmpty()) {
            Log.d(TAG, "Sending share data to Flutter: $shareData")
            if (::methodChannel.isInitialized) {
                methodChannel.invokeMethod("onShareReceived", shareData)
            } else {
                Log.w(TAG, "MethodChannel not initialized yet")
            }
         }
     }
     
     /**
      * 获取调用应用的包名
      */
     private fun getCallingPackage(intent: Intent): String {
         return try {
             // 尝试从Intent获取调用包名
             val callingPackage = callingActivity?.packageName
             if (!callingPackage.isNullOrEmpty()) {
                 Log.d(TAG, "Got calling package from callingActivity: $callingPackage")
                 return callingPackage
             }
             
             // 尝试从Intent的extras获取
             val packageName = intent.getStringExtra("android.intent.extra.REFERRER_NAME")
             if (!packageName.isNullOrEmpty()) {
                 Log.d(TAG, "Got package from REFERRER_NAME: $packageName")
                 return packageName.removePrefix("android-app://")
             }
             
             // 尝试从Intent的component获取
             val component = intent.component
             if (component != null) {
                 Log.d(TAG, "Got package from component: ${component.packageName}")
                 return component.packageName
             }
             
             Log.d(TAG, "Could not determine calling package, using unknown")
             "unknown"
         } catch (e: Exception) {
             Log.w(TAG, "Error getting calling package: ${e.message}")
             "unknown"
         }
     }
     
     /**
      * 处理文件URI，将content://协议的文件复制到应用可访问的位置
      */
     private fun processFileUri(uri: Uri): String? {
         return try {
             when (uri.scheme) {
                 "content" -> {
                     Log.d(TAG, "Processing content URI: $uri")
                     copyContentUriToInternalStorage(uri)
                 }
                 "file" -> {
                     Log.d(TAG, "Processing file URI: $uri")
                     uri.path
                 }
                 else -> {
                     Log.w(TAG, "Unsupported URI scheme: ${uri.scheme}")
                     null
                 }
             }
         } catch (e: Exception) {
             Log.e(TAG, "Failed to process URI: $uri", e)
             null
         }
     }
     
     /**
      * 将content://协议的文件复制到内部存储
      */
     private fun copyContentUriToInternalStorage(uri: Uri): String? {
         return try {
             val inputStream: InputStream? = contentResolver.openInputStream(uri)
             if (inputStream == null) {
                 Log.e(TAG, "Failed to open input stream for URI: $uri")
                 return null
             }
             
             // 生成唯一文件名
             val fileName = "shared_${UUID.randomUUID()}"
             val extension = getFileExtensionFromUri(uri)
             val fullFileName = if (extension.isNotEmpty()) "$fileName.$extension" else fileName
             
             // 创建内部存储文件
             val internalDir = File(filesDir, "shared_files")
             if (!internalDir.exists()) {
                 internalDir.mkdirs()
             }
             
             val internalFile = File(internalDir, fullFileName)
             val outputStream = FileOutputStream(internalFile)
             
             // 复制文件
             inputStream.use { input ->
                 outputStream.use { output ->
                     input.copyTo(output)
                 }
             }
             
             Log.d(TAG, "Successfully copied file to: ${internalFile.absolutePath}")
             internalFile.absolutePath
             
         } catch (e: Exception) {
             Log.e(TAG, "Failed to copy content URI to internal storage: $uri", e)
             null
         }
     }
     
     /**
      * 从URI获取文件扩展名
      */
     private fun getFileExtensionFromUri(uri: Uri): String {
         return try {
             val mimeType = contentResolver.getType(uri)
             when (mimeType) {
                 "image/jpeg" -> "jpg"
                 "image/png" -> "png"
                 "image/gif" -> "gif"
                 "image/webp" -> "webp"
                 "text/plain" -> "txt"
                 else -> {
                     // 尝试从URI路径获取扩展名
                     val path = uri.path
                     if (path != null && path.contains(".")) {
                         path.substringAfterLast(".")
                     } else {
                         "dat" // 默认扩展名
                     }
                 }
             }
         } catch (e: Exception) {
             Log.w(TAG, "Failed to get file extension for URI: $uri", e)
             "dat"
         }
     }
}
