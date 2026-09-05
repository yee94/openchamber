package com.yee94.openchamber

import android.annotation.SuppressLint
import android.content.Context
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class HtmlPreviewViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        return HtmlPreviewPlatformView(context, args as? Map<String, Any?>)
    }
}

class HtmlPreviewPlatformView(
    context: Context,
    args: Map<String, Any?>?,
) : PlatformView {
    @SuppressLint("SetJavaScriptEnabled")
    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        webViewClient = WebViewClient()
        setBackgroundColor(android.graphics.Color.TRANSPARENT)
        val html = args?.get("html") as? String ?: ""
        loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.destroy()
    }
}
