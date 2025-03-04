package com.tawakkal.tawakkal


import android.content.Context;
import android.content.Intent;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;

public class MethodChannelHandler implements MethodCallHandler {
    private final Context context;

    public MethodChannelHandler(Context context) {
        this.context = context;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("openApp")) {
            Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(intent);
                result.success(null);
            } else {
                result.error("ERROR", "Could not launch app", null);
            }
        } else {
            result.notImplemented();
        }
    }
}