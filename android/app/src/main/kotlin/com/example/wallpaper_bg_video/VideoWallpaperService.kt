package com.example.wallpaper_bg_video

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.common.C


class VideoWallpaperService : WallpaperService() {

    companion object {
        var currentVideoUri: String? = null
    }

    private var videoEngine: VideoEngine? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val newUri = intent?.getStringExtra("videoUri")
        Log.d("VideoWallpaperService", "URI recebida no serviço: $newUri")

        if (!newUri.isNullOrEmpty()) {
            currentVideoUri = newUri
            videoEngine?.updateVideo(newUri)
        }

        return START_STICKY
    }

    override fun onCreateEngine(): Engine {
        // Recupera a URI salva se o serviço foi reiniciado
        if (currentVideoUri == null) {
            val prefs = applicationContext.getSharedPreferences("wallpaper_prefs", Context.MODE_PRIVATE)
            currentVideoUri = prefs.getString("videoUri", null)
            Log.d("VideoWallpaperService", "Recuperando URI salva: $currentVideoUri")
        }

        videoEngine = VideoEngine(applicationContext)
        return videoEngine as VideoEngine
    }

    inner class VideoEngine(private val context: Context) : Engine() {
        private var player: ExoPlayer? = null
        private var surfaceHolderRef: SurfaceHolder? = null

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            surfaceHolderRef = holder
            Log.d("VideoWallpaperService", "Surface criada, iniciando player...")
            startPlayer(holder)
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            player?.setVideoSurface(holder.surface)
        }

        fun updateVideo(newUri: String) {
            if (surfaceHolderRef == null) {
                Log.e("VideoWallpaperService", "SurfaceHolder está nulo. Não é possível atualizar o vídeo.")
                return
            }

            try {
                if (player == null) {
                    Log.d("VideoWallpaperService", "Player não existe, chamando startPlayer.")
                    startPlayer(surfaceHolderRef!!)
                    return
                }

                Log.d("VideoWallpaperService", "Atualizando vídeo para: $newUri")
                player?.stop()
                player?.clearMediaItems()
                val mediaItem = MediaItem.fromUri(Uri.parse(newUri))
                player?.setMediaItem(mediaItem)
                player?.prepare()
                player?.playWhenReady = true
            } catch (e: Exception) {
                Log.e("VideoWallpaperService", "Erro ao atualizar vídeo: ${e.message}")
            }
        }

        private fun startPlayer(holder: SurfaceHolder) {
            stopPlayer() // Garante que não haja um player antigo
            val videoPath = currentVideoUri
            Log.d("VideoWallpaperService", "Caminho do vídeo usado: $videoPath")

            if (videoPath.isNullOrEmpty()) {
                Log.e("VideoWallpaperService", "Nenhum vídeo definido.")
                return
            }

            try {
                player = ExoPlayer.Builder(context).build().apply {
                    setVideoSurface(holder.surface)
                    val mediaItem = MediaItem.fromUri(Uri.parse(videoPath))
                    setMediaItem(mediaItem)
                    videoScalingMode = C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
                    repeatMode = ExoPlayer.REPEAT_MODE_ALL
                    volume = 0f
                    prepare()
                    playWhenReady = true
                }

                Log.d("VideoWallpaperService", "Player pronto e reproduzindo.")
            } catch (e: Exception) {
                Log.e("VideoWallpaperService", "Erro ao iniciar player: ${e.message}")
            }
        }

        private fun stopPlayer() {
            player?.release()
            player = null
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            surfaceHolderRef = null
            stopPlayer()
        }
    }
}
