package com.misaigon.micharity;

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import java.io.File;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.misaigon.micharity/installer";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(new MethodChannel.MethodCallHandler() {
                @Override
                public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                    if (call.method.equals("installApk")) {
                        String filePath = call.argument("filePath");
                        if (filePath != null) {
                            try {
                                File file = new File(filePath);
                                if (!file.exists()) {
                                    result.error("FILE_NOT_FOUND", "File does not exist: " + filePath, null);
                                    return;
                                }

                                Intent intent = new Intent(Intent.ACTION_VIEW);
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

                                Uri apkUri;
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    apkUri = FileProvider.getUriForFile(
                                        MainActivity.this,
                                        getApplicationContext().getPackageName() + ".fileprovider",
                                        file
                                    );
                                } else {
                                    apkUri = Uri.fromFile(file);
                                }

                                intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
                                startActivity(intent);
                                result.success(true);
                            } catch (Exception e) {
                                result.error("INSTALL_ERROR", e.getMessage(), null);
                            }
                        } else {
                            result.error("INVALID_PATH", "File path is null", null);
                        }
                    } else {
                        result.notImplemented();
                    }
                }
            });
    }
}
