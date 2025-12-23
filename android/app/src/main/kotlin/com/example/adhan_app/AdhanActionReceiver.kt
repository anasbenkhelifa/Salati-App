package com.example.adhan_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver to handle STOP action for Adhan playback.
 * Works even when Flutter engine is not running.
 */
class AdhanActionReceiver : BroadcastReceiver() {
    
    companion object {
        const val TAG = "AdhanActionReceiver"
        const val ACTION_STOP_ADHAN = "com.example.adhan_app.ACTION_STOP_ADHAN"
    }
    
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        
        Log.d(TAG, "Received action: $action")
        
        when (action) {
            ACTION_STOP_ADHAN -> {
                Log.d(TAG, "Stopping Adhan playback")
                AdhanForegroundService.getInstance()?.stopAdhanPlayback()
            }
        }
    }
}
