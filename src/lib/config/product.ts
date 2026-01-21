export const productConfig = {
  name: "AI Video Generator",
  envBanner: process.env.NEXT_PUBLIC_ENV_BANNER ?? "DEV",
  features: {
    adminEnabled: false,
    showComingSoon: true,
  },
  generatorModes: [
    { key: "text", label: "Text-to-video", enabled: true },
    { key: "image", label: "Image-to-video", enabled: true },
    { key: "extend", label: "Extend", enabled: true },
    { key: "restyle", label: "Restyle", enabled: true },
    { key: "storyboard", label: "Storyboard", enabled: false },
    { key: "audio", label: "Audio-only", enabled: false },
  ],
  stylePresets: [
    "Cinematic",
    "Documentary",
    "Product render",
    "Illustrated",
    "Neon noir",
  ],
  cameraMoves: ["Static", "Dolly in", "Pan", "Orbit", "Handheld"],
  aspectRatios: ["16:9", "9:16", "1:1"],
  durations: ["8s", "16s", "32s"],
  qualities: ["Draft", "Standard", "Ultra"],
} as const;
