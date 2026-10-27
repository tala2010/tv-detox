package dev.local.mitvhome;

/** Native source IDs verified on MiTV-MFTP0. Not a generic MediaTek mapping. */
final class XiaomiInputs {
    private static final String HDMI = "com.mediatek.tvinput/.hdmi.HDMIInputService/HW";

    static int nativeInput(String id) {
        if ((HDMI + "5").equals(id)) return 23;
        if ((HDMI + "6").equals(id)) return 24;
        if ((HDMI + "7").equals(id)) return 25;
        return -1;
    }

    static boolean isPhantom(String model, String id) {
        return "MiTV-MFTP0".equals(model) && (HDMI + "8").equals(id);
    }
}
