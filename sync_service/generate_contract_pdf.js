const fs = require('fs');
const path = require('path');
const { PDFDocument, StandardFonts, rgb } = require('pdf-lib');

/**
 * Generates an official 3-page Ejari Tenancy Contract PDF filled with database values.
 * @param {Object} contractData Database contract record
 * @param {string} outputPath Target path to save the generated PDF
 * @returns {Promise<string>} outputPath
 */
async function generateEjariContractPdf(contractData, outputPath) {
  // Locate official Ejari template
  let templatePath = path.resolve(__dirname, 'ejari_template.pdf');
  if (!fs.existsSync(templatePath)) {
    templatePath = 'C:/Users/Abdullah/.gemini/antigravity/brain/084ba85d-e68d-4bf5-ac7a-7890a99491f4/.user_uploaded/media_1793650229415_c4456f24.pdf';
  }

  const templateBytes = fs.readFileSync(templatePath);
  const pdfDoc = await PDFDocument.load(templateBytes);

  const helveticaBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const helvetica = await pdfDoc.embedFont(StandardFonts.Helvetica);

  const page = pdfDoc.getPage(0);
  const ink = rgb(0.05, 0.12, 0.35); // Official deep navy ink
  const red = rgb(0.65, 0.08, 0.08); // Accent red

  const draw = (text, x, y, size = 9, isBold = true, color = ink) => {
    if (!text) return;
    page.drawText(String(text), {
      x,
      y,
      size,
      font: isBold ? helveticaBold : helvetica,
      color
    });
  };

  // Helper date formatter
  const formatDate = (d) => {
    if (!d) return '';
    const dt = new Date(d);
    if (isNaN(dt.getTime())) return String(d);
    const day = String(dt.getDate()).padStart(2, '0');
    const month = String(dt.getMonth() + 1).padStart(2, '0');
    return `${day}/${month}/${dt.getFullYear()}`;
  };

  const startDateStr = formatDate(contractData.startDate || new Date());
  const endDateStr = formatDate(contractData.endDate);
  const rentStr = (contractData.rentAmount || contractData.yearValue || 0).toLocaleString() + ' AED';

  // 1. Header (Date & Reference Code)
  draw(startDateStr, 80, 725, 10, true, ink);
  const refCode = (contractData.contractCode || '') + (contractData.contractNumber ? ` (#${contractData.contractNumber})` : '');
  draw(refCode ? `Ref: ${refCode}` : '', 230, 725, 10, true, red);

  // 2. Owner / Lessor Info
  draw('Saeed BinShafar', 120, 679, 9.5);
  draw('Saeed BinShafar Properties', 120, 654, 9.5);
  draw('784-1970-1234567-1', 160, 629, 9);
  draw('CN-1092847', 160, 604, 9);
  draw('DED Dubai', 380, 604, 9);
  draw('info@elitelivingre.com', 160, 579, 9);
  draw('00971522807077', 160, 554, 9);

  // 3. Tenant Info
  draw(contractData.tenantName || 'Tenant', 120, 509, 10, true, red);
  draw(contractData.emiratesId || '784-XXXX-XXXXXXX-X', 160, 484, 9);
  draw('N/A (Individual)', 160, 459, 8.5, false);
  draw('N/A (Individual)', 380, 459, 8.5, false);
  draw(contractData.customerEmail || contractData.email || 'N/A', 160, 434, 9);
  draw(contractData.mobileNumber || contractData.phone || 'N/A', 160, 409, 9.5);

  // 4. Property Info
  // Residential indicator dot
  page.drawCircle({ x: 370, y: 356, size: 3.5, color: ink });
  draw('Plot: ' + (contractData.plotNo || '373-1245'), 80, 331, 9);
  draw('Makani: ' + (contractData.makaniNo || '28472 91834'), 320, 331, 9);
  draw(contractData.buildingName || '', 80, 306, 8.5);
  draw('Unit: ' + (contractData.unitNumber || ''), 320, 306, 9.5, true, red);
  draw(contractData.unitType || 'Apartment', 80, 281, 9);
  draw(contractData.propertyArea || 'Standard', 320, 281, 9);
  draw(contractData.location || 'Dubai, UAE', 80, 256, 9);
  draw('DEWA: ' + (contractData.dewaNo || 'N/A'), 320, 256, 9);

  // 5. Contract Info
  draw(`${startDateStr}   to   ${endDateStr}`, 120, 208, 9, true);
  draw(rentStr, 340, 208, 9.5, true, red);
  draw(rentStr, 120, 183, 9.5, true, red);
  const deposit = Math.round((contractData.rentAmount || contractData.yearValue || 0) * 0.05);
  draw(deposit > 0 ? `${deposit.toLocaleString()} AED (5%)` : 'N/A', 340, 183, 9);
  const chequesCount = contractData.chequesCount || 4;
  draw(`${chequesCount} Cheques (Standard installments)`, 140, 158, 9);

  // 6. Signatures Date
  draw(startDateStr, 205, 45, 8.5);
  draw(startDateStr, 475, 45, 8.5);

  const pdfOutput = await pdfDoc.save();
  fs.writeFileSync(outputPath, pdfOutput);
  return outputPath;
}

module.exports = { generateEjariContractPdf };
