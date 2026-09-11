package com.misaigon.micharity;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.media.ToneGenerator;
import android.net.Uri;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.Ndef;
import android.os.Build;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.Settings;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL_INSTALLER = "com.misaigon.micharity/installer";
    private static final String CHANNEL_AUDIO = "com.misaigon.micharity/audio";
    private static final String CHANNEL_NFC = "com.misaigon.micharity/nfc";

    private short[] solSamples;
    private short[] doSamples;
    private MethodChannel nfcChannel;
    private NfcAdapter nfcAdapter;
    private boolean isNfcScanning = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        initBeepSamples();

        // Installer Channel
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_INSTALLER)
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
                    } else if (call.method.equals("openHomeSettings")) {
                        try {
                            Intent intent;
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                intent = new Intent(Settings.ACTION_HOME_SETTINGS);
                            } else {
                                intent = new Intent(Settings.ACTION_SETTINGS);
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception e) {
                            try {
                                Intent intent = new Intent(Settings.ACTION_SETTINGS);
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                                startActivity(intent);
                                result.success(true);
                            } catch (Exception ex) {
                                result.error("SETTINGS_ERROR", ex.getMessage(), null);
                            }
                        }
                    } else {
                        result.notImplemented();
                    }
                }
            });

        // Native Audio Channel (ToneGenerator + AudioTrack direct output + Vibrator)
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_AUDIO)
            .setMethodCallHandler(new MethodChannel.MethodCallHandler() {
                @Override
                public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                    if (call.method.equals("playScanBeep") || call.method.equals("playBeep")) {
                        // Nốt Sol (G4: 392Hz) khi Quét thành công
                        triggerNativeVibration(120);
                        playNativeSolBeep();
                        result.success(true);
                    } else if (call.method.equals("playConfirmBeep")) {
                        // Nốt Đô (C4: 261Hz) khi Xác nhận thành công
                        triggerNativeVibration(180);
                        playNativeDoBeep();
                        result.success(true);
                    } else if (call.method.equals("vibrate")) {
                        triggerNativeVibration(150);
                        result.success(true);
                    } else {
                        result.notImplemented();
                    }
                }
            });

        // Native NFC Channel
        nfcChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL_NFC);
        nfcChannel.setMethodCallHandler(new MethodChannel.MethodCallHandler() {
            @Override
            public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
                if (call.method.equals("isNfcHardwarePresent")) {
                    try {
                        NfcAdapter adapter = NfcAdapter.getDefaultAdapter(MainActivity.this);
                        result.success(adapter != null);
                    } catch (Exception e) {
                        result.success(false);
                    }
                } else if (call.method.equals("isNfcEnabled")) {
                    try {
                        NfcAdapter adapter = NfcAdapter.getDefaultAdapter(MainActivity.this);
                        result.success(adapter != null && adapter.isEnabled());
                    } catch (Exception e) {
                        result.success(false);
                    }
                } else if (call.method.equals("startScan")) {
                    isNfcScanning = true;
                    enableNfcScanning();
                    result.success(true);
                } else if (call.method.equals("stopScan")) {
                    if (!isNfcScanning) {
                        result.success(true);
                        return;
                    }
                    isNfcScanning = false;
                    disableNfcScanning();
                    result.success(true);
                } else if (call.method.equals("openNfcSettings")) {
                    try {
                        Intent intent = new Intent(Settings.ACTION_NFC_SETTINGS);
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        startActivity(intent);
                        result.success(true);
                    } catch (Exception e) {
                        try {
                            Intent intent = new Intent(Settings.ACTION_WIRELESS_SETTINGS);
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        } catch (Exception ex) {
                            Intent intent = new Intent(Settings.ACTION_SETTINGS);
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(intent);
                            result.success(true);
                        }
                    }
                } else {
                    result.notImplemented();
                }
            }
        });
    }

    private void logToFlutter(String message) {
        android.util.Log.d("MiCharityNFC", message);
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (nfcChannel != null) {
                    try {
                        nfcChannel.invokeMethod("onNativeLog", message);
                    } catch (Exception ignored) {}
                }
            }
        });
    }

    private void enableNfcScanning() {
        if (nfcAdapter == null) {
            nfcAdapter = NfcAdapter.getDefaultAdapter(this);
        }
        if (nfcAdapter == null) {
            logToFlutter("enableNfcScanning: nfcAdapter is null (device has no NFC hardware)");
            return;
        }
        if (!nfcAdapter.isEnabled()) {
            logToFlutter("enableNfcScanning: NFC is DISABLED in system settings!");
            return;
        }

        logToFlutter("Starting NFC ReaderMode on " + Build.MANUFACTURER + " " + Build.MODEL + " (Android " + Build.VERSION.RELEASE + ", SDK " + Build.VERSION.SDK_INT + ")");

        // 1. Tắt foreground dispatch và ReaderMode nếu còn sót để reset HAL
        try {
            nfcAdapter.disableForegroundDispatch(this);
        } catch (Exception ignored) {}
        try {
            nfcAdapter.disableReaderMode(this);
        } catch (Exception ignored) {}

        // 2. Kích hoạt ReaderMode với các cờ chuẩn cho tất cả các thẻ RFID/NFC
        // BỎ FLAG_READER_NFC_BARCODE (Kovio) vì gây lỗi phần cứng trên Samsung SM-A236E
        // GIỮ FLAG_READER_SKIP_NDEF_CHECK để nhận ngay thẻ RFID trắng / Mifare Classic
        try {
            int flags = NfcAdapter.FLAG_READER_NFC_A |
                        NfcAdapter.FLAG_READER_NFC_B |
                        NfcAdapter.FLAG_READER_NFC_F |
                        NfcAdapter.FLAG_READER_NFC_V |
                        NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK |
                        NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS;

            nfcAdapter.enableReaderMode(this, new NfcAdapter.ReaderCallback() {
                @Override
                public void onTagDiscovered(Tag tag) {
                    logToFlutter(">>> Tag discovered via ReaderCallback! Tech: " + java.util.Arrays.toString(tag.getTechList()));
                    onTagDiscoveredInternal(tag);
                }
            }, flags, null);

            logToFlutter("enableReaderMode activated successfully! Anten NFC is actively listening for cards...");
        } catch (Exception e) {
            logToFlutter("enableReaderMode failed: " + e.getMessage() + ", falling back to ForegroundDispatch");
            enableForegroundDispatchFallback();
        }
    }

    private void enableForegroundDispatchFallback() {
        try {
            Intent intent = new Intent(this, getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            int pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                pendingFlags |= PendingIntent.FLAG_MUTABLE;
            }
            PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingFlags);
            nfcAdapter.enableForegroundDispatch(this, pendingIntent, null, null);
            logToFlutter("Fallback enableForegroundDispatch activated");
        } catch (Exception ex) {
            logToFlutter("enableForegroundDispatchFallback error: " + ex.getMessage());
        }
    }

    private void disableNfcScanning() {
        if (nfcAdapter != null) {
            try {
                nfcAdapter.disableReaderMode(this);
                logToFlutter("ReaderMode disabled");
            } catch (Exception ignored) {}
            try {
                nfcAdapter.disableForegroundDispatch(this);
            } catch (Exception ignored) {}
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        logToFlutter("MainActivity onResume (isNfcScanning=" + isNfcScanning + ")");
        if (isNfcScanning) {
            enableNfcScanning();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        logToFlutter("MainActivity onPause");
        if (isNfcScanning) {
            disableNfcScanning();
        }
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        logToFlutter(">>> onNewIntent received! Action: " + intent.getAction());

        Tag tag = null;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag.class);
            }
        } catch (Throwable ignored) {}
        if (tag == null) {
            try {
                tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
            } catch (Throwable ignored) {}
        }

        if (tag != null) {
            logToFlutter("Tag extracted successfully from onNewIntent! ID length: " + (tag.getId() != null ? tag.getId().length : 0));
            onTagDiscoveredInternal(tag);
        } else {
            logToFlutter("WARNING: onNewIntent received but EXTRA_TAG is null! Action: " + intent.getAction() + ", Extras: " + intent.getExtras());
        }
    }

    private void onTagDiscoveredInternal(Tag tag) {
        final Map<String, Object> map = parseTagToMap(tag);
        logToFlutter("Tag detected! UID: " + map.get("uidHex") + ", Standards: " + map.get("technologies"));
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (nfcChannel != null) {
                    nfcChannel.invokeMethod("onCardDetected", map);
                }
            }
        });
    }

    private Map<String, Object> parseTagToMap(Tag tag) {
        Map<String, Object> map = new HashMap<>();
        byte[] idBytes = tag.getId();
        if (idBytes != null && idBytes.length > 0) {
            StringBuilder sbHex = new StringBuilder();
            StringBuilder sbRaw = new StringBuilder();
            for (int i = 0; i < idBytes.length; i++) {
                String hex = String.format("%02X", idBytes[i]);
                sbRaw.append(hex);
                if (i > 0) sbHex.append(":");
                sbHex.append(hex);
            }
            map.put("uidHex", sbHex.toString());
            map.put("uidRawHex", sbRaw.toString());
            map.put("idBytes", idBytes);
        } else {
            map.put("uidHex", "UNKNOWN");
            map.put("uidRawHex", "UNKNOWN");
            map.put("idBytes", new byte[0]);
        }

        String[] techList = tag.getTechList();
        List<String> technologies = new ArrayList<>();
        if (techList != null) {
            for (String tech : techList) {
                String simpleName = tech.substring(tech.lastIndexOf('.') + 1);
                technologies.add(simpleName);
            }
        }
        map.put("technologies", technologies);

        // Đọc NDEF nếu có
        try {
            Ndef ndef = Ndef.get(tag);
            if (ndef != null) {
                NdefMessage cached = ndef.getCachedNdefMessage();
                if (cached != null) {
                    NdefRecord[] records = cached.getRecords();
                    if (records != null && records.length > 0) {
                        StringBuilder ndefStr = new StringBuilder();
                        for (NdefRecord record : records) {
                            try {
                                String type = new String(record.getType(), "UTF-8");
                                String payload = new String(record.getPayload(), "UTF-8");
                                if (ndefStr.length() > 0) ndefStr.append("; ");
                                ndefStr.append("[").append(type).append(": ").append(payload).append("]");
                            } catch (Exception ignored) {}
                        }
                        map.put("ndefPayload", ndefStr.toString());
                    }
                }
            }
        } catch (Exception ignored) {}

        return map;
    }

    private void initBeepSamples() {
        try {
            int sampleRate = 44100;

            // 1. Nốt Sol (G4 = 392.00 Hz, G5 = 783.99 Hz, G6 = 1567.98 Hz) - 180ms
            int numSol = sampleRate * 180 / 1000;
            solSamples = new short[numSol];
            double solG4 = 392.00;
            double solG5 = 783.99;
            double solG6 = 1567.98;
            int solAttack = sampleRate * 15 / 1000;
            int solDecay = sampleRate * 60 / 1000;
            int solSustainEnd = numSol - solDecay;

            for (int i = 0; i < numSol; ++i) {
                double t = (double) i / sampleRate;
                double envelope = 1.0;
                if (i < solAttack) {
                    envelope = (double) i / solAttack;
                } else if (i > solSustainEnd) {
                    envelope = (double) (numSol - i) / solDecay;
                }
                double wave = Math.sin(2 * Math.PI * solG4 * t) * 0.35 +
                              Math.sin(2 * Math.PI * solG5 * t) * 0.45 +
                              Math.sin(2 * Math.PI * solG6 * t) * 0.20;
                solSamples[i] = (short) (wave * 32767 * envelope * 0.9);
            }

            // 2. Nốt Do (C4 = 261.63 Hz, C5 = 523.25 Hz, C6 = 1046.50 Hz) - 320ms
            int numDo = sampleRate * 320 / 1000;
            doSamples = new short[numDo];
            double doC4 = 261.63;
            double doC5 = 523.25;
            double doC6 = 1046.50;
            int doAttack = sampleRate * 20 / 1000;
            int doDecay = sampleRate * 160 / 1000;
            int doSustainEnd = numDo - doDecay;

            for (int i = 0; i < numDo; ++i) {
                double t = (double) i / sampleRate;
                double envelope = 1.0;
                if (i < doAttack) {
                    envelope = (double) i / doAttack;
                } else if (i > doSustainEnd) {
                    envelope = (double) (numDo - i) / doDecay;
                }
                double wave = Math.sin(2 * Math.PI * doC4 * t) * 0.40 +
                              Math.sin(2 * Math.PI * doC5 * t) * 0.45 +
                              Math.sin(2 * Math.PI * doC6 * t) * 0.15;
                doSamples[i] = (short) (wave * 32767 * envelope * 0.9);
            }

        } catch (Exception ignored) {}
    }

    private void triggerNativeVibration(int durationMs) {
        try {
            Vibrator v = (Vibrator) getSystemService(Context.VIBRATOR_SERVICE);
            if (v != null && v.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    v.vibrate(durationMs);
                }
            }
        } catch (Exception ignored) {}
    }

    private void playNativeSolBeep() {
        if (solSamples == null) {
            initBeepSamples();
        }
        playPcmTrack(solSamples, 250);
    }

    private void playNativeDoBeep() {
        if (doSamples == null) {
            initBeepSamples();
        }
        playPcmTrack(doSamples, 400);
    }

    private void playPcmTrack(final short[] pcm, int releaseDelayMs) {
        if (pcm == null) return;
        try {
            int sampleRate = 44100;
            AudioAttributes audioAttributes = new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build();

            AudioFormat audioFormat = new AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build();

            int minBufferSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            );
            int bufferSize = Math.max(pcm.length * 2, minBufferSize > 0 ? minBufferSize : 4096);

            final AudioTrack track = new AudioTrack(
                audioAttributes,
                audioFormat,
                bufferSize,
                AudioTrack.MODE_STATIC,
                AudioManager.AUDIO_SESSION_ID_GENERATE
            );

            track.write(pcm, 0, pcm.length);
            track.setVolume(1.0f);
            track.play();

            new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(new Runnable() {
                @Override
                public void run() {
                    try {
                        track.stop();
                        track.release();
                    } catch (Exception ignored) {}
                }
            }, releaseDelayMs);
        } catch (Exception e) {
            try {
                final ToneGenerator tg = new ToneGenerator(AudioManager.STREAM_MUSIC, 100);
                tg.startTone(ToneGenerator.TONE_PROP_BEEP, 200);
                new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            tg.release();
                        } catch (Exception ignored) {}
                    }
                }, 300);
            } catch (Exception ignored) {}
        }
    }
}

