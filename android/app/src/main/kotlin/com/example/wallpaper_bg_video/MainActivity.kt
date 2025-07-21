package com.example.wallpaper_bg_video

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.service.wallpaper.WallpaperService
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.WallpaperManager
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private val CHANNEL = "wallpaper.channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "openLiveWallpaperPicker" -> {
                        try {
                            val intent = Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Erro ao abrir seletor de wallpaper", e)
                            result.error("UNAVAILABLE", "Erro ao abrir seletor", null)
                        }
                    }

                    "setWallpaper" -> {
                        val videoUri = call.argument<String>("videoUri")
                        if (videoUri != null) {
                            try {
                                VideoWallpaperService.currentVideoUri = videoUri
                                val intent = Intent(this, VideoWallpaperService::class.java)
                                intent.putExtra("videoUri", videoUri)
                                startService(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e("MainActivity", "Erro ao iniciar serviço de wallpaper", e)
                                result.error("UNAVAILABLE", "Erro ao iniciar serviço", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "URI de vídeo ausente", null)
                        }
                    }



                    else -> result.notImplemented()
                }
            }

    }
}
