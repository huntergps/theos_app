import * as pdfjsLib from './pdfjs/4.10.38/build/pdf.min.mjs';

const pdfJsBaseUrl = new URL('./pdfjs/4.10.38/build/', import.meta.url);
pdfjsLib.GlobalWorkerOptions.workerSrc = new URL(
  'pdf.worker.min.mjs',
  pdfJsBaseUrl,
).href;

// Syncfusion resolves the global library, while consumers that understand the
// Printing convention can resolve the same self-hosted base path.
window.pdfjsLib = pdfjsLib;
window.dartPdfJsBaseUrl = pdfJsBaseUrl.href;
window.dartPdfJsVersion = '4.10.38';

// Load Flutter only after PDF.js is ready. This removes the initialization
// race without relying on inline code or an external CDN.
const flutterBootstrap = document.createElement('script');
flutterBootstrap.src = new URL('./flutter_bootstrap.js', import.meta.url).href;
document.body.appendChild(flutterBootstrap);
