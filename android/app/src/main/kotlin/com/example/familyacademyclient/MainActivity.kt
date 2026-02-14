package com.example.familyacademyclient

import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.familyacademy/screen_protection"
    private var isVideoPlaying = false
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "protectScreen" -> {
                    protectScreen()
                    result.success(true)
                }
                "unprotectScreen" -> {
                    unprotectScreen()
                    result.success(true)
                }
                "protectVideo" -> {
                    protectForVideo()
                    result.success(true)
                }
                "restoreFromVideo" -> {
                    restoreFromVideo()
                    result.success(true)
                }
                "disableSplitScreen" -> {
                    disableSplitScreen()
                    result.success(true)
                }
                "setSystemUiMode" -> {
                    val mode = call.arguments as? String
                    setSystemUiMode(mode)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Disable split-screen and multi-window
        disableSplitScreen()
        
        // Initial screen protection
        protectScreen()
    }
    
    private fun protectScreen() {
        runOnUiThread {
            // FLAG_SECURE - prevent screenshots and screen recording
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
            
            // Additional flags for better protection
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            
            // Use safe SystemUiMode for all Android versions
            setSafeSystemUiMode()
            
            // For Android Q (10) and above, add more secure flags
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.attributes.layoutInDisplayCutoutMode = 
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER
            }
        }
    }
    
    private fun setSafeSystemUiMode() {
        runOnUiThread {
            val decorView = window.decorView
            
            // Use a safe combination of flags that works on all Android versions
            var flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_FULLSCREEN)
            
            // Add immersive sticky for better experience on supported versions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                flags = flags or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            }
            
            decorView.systemUiVisibility = flags
        }
    }
    
    private fun setSystemUiMode(mode: String?) {
        runOnUiThread {
            val decorView = window.decorView
            
            when (mode) {
                "edgeToEdge" -> {
                    // Edge-to-edge mode for newer Android versions
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        window.attributes.layoutInDisplayCutoutMode = 
                            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                    }
                    decorView.systemUiVisibility = (
                        View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    )
                }
                "immersive" -> {
                    // Immersive mode
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        decorView.systemUiVisibility = (
                            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        )
                    } else {
                        // Fallback for older versions
                        decorView.systemUiVisibility = (
                            View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                        )
                    }
                }
                else -> {
                    // Default mode
                    setSafeSystemUiMode()
                }
            }
        }
    }
    
    private fun unprotectScreen() {
        runOnUiThread {
            // Only remove secure flag if not playing video
            if (!isVideoPlaying) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            
            // Restore normal system UI
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            
            // Restore normal navigation bar
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.attributes.layoutInDisplayCutoutMode = 
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_DEFAULT
            }
        }
    }
    
    private fun protectForVideo() {
        isVideoPlaying = true
        runOnUiThread {
            // Extra protection for video playback
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
            
            // Keep screen on during video
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            
            // Fullscreen for video
            window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
            
            // Set immersive mode for video
            setSystemUiMode("immersive")
        }
    }
    
    private fun restoreFromVideo() {
        isVideoPlaying = false
        protectScreen() // Restore normal protection
    }
    
    private fun disableSplitScreen() {
        // Make activity non-resizable
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            if (!isInMultiWindowMode) {
                // Already not in multi-window, ensure it stays that way
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        // Re-apply protection on resume
        protectScreen()
    }
    
    override fun onPause() {
        super.onPause()
        // Only remove non-video protection
        if (!isVideoPlaying) {
            unprotectScreen()
        }
    }
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Re-apply protection when window gains focus
            protectScreen()
        }
    }
    
    // Prevent entering multi-window mode
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean) {
        super.onMultiWindowModeChanged(isInMultiWindowMode)
        if (isInMultiWindowMode) {
            // If somehow entered multi-window, finish activity
            finish()
        }
    }
}