import { Buffer } from "node:buffer";
import { imageSize } from "npm:image-size@2.0.2";
import { decode, encode } from "npm:jpeg-js@0.4.4";
// @deno-types="npm:@types/pngjs@6.0.5"
import { PNG } from "npm:pngjs@7.0.0";

// Pure JS dependencies are bundled by Dashboard deployment. No separate WASM
// file or runtime filesystem access is required. Android normalizes WebP to JPEG.
export async function sanitizeReviewImage(bytes: Uint8Array) {
  if (bytes.length === 0 || bytes.length > 5242880) {
    throw new Error("Use a photo under 5 MB.");
  }
  const size = imageSize(bytes);
  if (
    !["jpg", "png"].includes(size.type ?? "") || size.width < 100 ||
    size.height < 100 ||
    size.width > 6000 || size.height > 6000 ||
    size.width * size.height > 6000000
  ) {
    throw new Error("Use a JPG or PNG photo, 100-6000 px and up to 6 MP.");
  }
  let pixels: Uint8Array;
  let width: number, height: number;
  if (size.type === "jpg") {
    const decoded = decode(bytes, {
      useTArray: true,
      formatAsRGBA: true,
      tolerantDecoding: false,
      maxResolutionInMP: 6,
      maxMemoryUsageInMB: 96,
    });
    ({ width, height } = decoded);
    pixels = decoded.data;
  } else {
    // Android emits JPEG; PNG remains supported for existing clients. Bound the
    // bit depth as well as dimensions before inflating untrusted bytes.
    if (bytes[24] > 8) throw new Error("Choose an 8-bit PNG or JPEG photo.");
    const decoded = PNG.sync.read(Buffer.from(bytes), { checkCRC: true });
    ({ width, height } = decoded);
    pixels = decoded.data;
    for (let i = 0; i < pixels.length; i += 4) {
      const alpha = pixels[i + 3] / 255;
      for (let c = 0; c < 3; c++) {
        pixels[i + c] = Math.round(pixels[i + c] * alpha + 255 * (1 - alpha));
      }
      pixels[i + 3] = 255;
    }
  }
  if (
    width !== size.width || height !== size.height ||
    pixels.length !== width * height * 4
  ) {
    throw new Error("Invalid photo dimensions.");
  }
  // Fresh pixels only: never copy EXIF, comments, filenames or embedded payloads.
  const result = Uint8Array.from(
    encode({ width, height, data: pixels }, 82).data,
  );
  if (result.length > 5242880) throw new Error("Choose a smaller photo.");
  return { bytes: result, width, height, mime: "image/jpeg" };
}
