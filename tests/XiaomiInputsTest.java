package dev.local.mitvhome;

public final class XiaomiInputsTest {
    public static void main(String[] args) {
        String hdmi = "com.mediatek.tvinput/.hdmi.HDMIInputService/HW";
        expect(XiaomiInputs.nativeInput(hdmi + "5") == 23, "HDMI 1 must select native source 23");
        expect(XiaomiInputs.nativeInput(hdmi + "6") == 24, "HDMI 2 must select native source 24");
        expect(XiaomiInputs.nativeInput(hdmi + "7") == 25, "HDMI 3 must select native source 25");
        for (String id : new String[] {null, "", hdmi + "8", hdmi + "50", "other/.hdmi.HDMIInputService/HW5"})
            expect(XiaomiInputs.nativeInput(id) == -1, "Unknown inputs must not switch to a guessed source");
        expect(XiaomiInputs.isPhantom("MiTV-MFTP0", hdmi + "8"), "Hide this model's nonphysical fourth input");
        expect(!XiaomiInputs.isPhantom("OtherTV", hdmi + "8"), "Do not hide a fourth port on another TV");
        expect(!XiaomiInputs.isPhantom("MiTV-MFTP0", hdmi + "7"), "Keep the physical third port");
        System.out.println("PASS: Xiaomi input mapping and model-specific phantom filtering");
    }

    private static void expect(boolean ok, String message) {
        if (!ok) throw new AssertionError(message);
    }
}
