package com.openchamber.app;

import android.view.HapticFeedbackConstants;
import android.webkit.WebView;
import com.getcapacitor.Bridge;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "OpenChamberHaptics")
public class OpenChamberHapticsPlugin extends Plugin {
    @PluginMethod(returnType = PluginMethod.RETURN_NONE)
    public void impactLight(PluginCall call) {
        Bridge bridge = getBridge();
        if (bridge == null) return;

        WebView webView = bridge.getWebView();
        if (webView == null) return;

        webView.post(() -> {
            if (!webView.isAttachedToWindow()) return;
            webView.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP);
        });
    }
}
