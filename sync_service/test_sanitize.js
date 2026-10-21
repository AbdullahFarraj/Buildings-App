function sanitizeUaeMobileImproved(rawMobile) {
  if (!rawMobile) return null;

  // First, if there are multiple phones separated by slash or comma, take the first part
  let firstPart = rawMobile.toString().split(/[\/,;]+/)[0].trim();

  // Remove ALL non-digit characters (including spaces, newlines, tabs, dashes, plus)
  let digits = firstPart.replace(/\D/g, '');

  if (!digits) return null;

  // Handle accidental 97105xxxxxxx -> 9715xxxxxxx
  if (digits.startsWith('97105') && digits.length === 13) {
    digits = '9715' + digits.substring(5);
  }

  // Handle 009715...
  if (digits.startsWith('009715') && digits.length === 14) {
    digits = digits.substring(2);
  }

  // Handle 05xxxxxxxx -> 9715xxxxxxxx
  if (digits.startsWith('05') && digits.length === 10) {
    digits = '971' + digits.substring(1);
  }

  // Handle 5xxxxxxxx -> 9715xxxxxxxx
  if (digits.startsWith('5') && digits.length === 9) {
    digits = '971' + digits;
  }

  // Check valid UAE mobile
  if (digits.length === 12 && digits.startsWith('9715')) {
    return digits;
  }

  return null;
}

const testCases = [
  "+971 52 256 0167",
  "052 280 7077",
  "055 721 7334",
  "\n971527208823",
  "9710542256010",
  "+971 50 655 0373",
  "971 55 224 7423"
];

testCases.forEach(tc => {
  console.log(`"${tc.replace(/\n/g, '\\n')}" ->`, sanitizeUaeMobileImproved(tc));
});
