// grumpy-loading page settings. Plain values only; this file is loaded by the loading screen itself.
// On-screen text lives in ../locales/<locale>.json.
window.GAZETTE_CONFIG = {
  // Language file in locales/ (en.json ships with the resource).
  locale: 'en',

  // Server logo, framed in the masthead's left corner (replaces the left corner text). Blank = text only.
  logo: 'images/logo.webp',

  // The dateline shows today's month and day in this year, e.g. "Thursday, November 5, 1899".
  year: 1899,

  // The issue number counts days since this date (YYYY-MM-DD). Issue No. 1 is printed on this day.
  firstIssue: '2026-11-05',

  // Seconds between front-page stories, and between notices in the side column.
  storySeconds: 14,
  noticeSeconds: 8,

  // Music: a file in html/music/ (add new files to that folder; the manifest already serves music/*).
  // Leave blank for no music. Players press SPACE to mute or unmute.
  music: 'music/song2.mp3',
  musicVolume: 0.3,          // 0.0 - 1.0
  musicFadeSeconds: 1.0,     // fade out when the screen closes

  // Photographs behind the newspaper: files in html/images/ or full URLs. Several = a slideshow.
  // Empty = a plain dark desk.
  backgrounds: [],
  backgroundSeconds: 15,
  backgroundDim: 0.55,       // 0 = full brightness, 1 = black

  // Shown in the WANTED poster. Leave blank to hide the line.
  discord: '',

  // Safety net: close the screen after this many seconds if nothing else does. 0 = never.
  // rsg-character closes it at character selection, so this rarely matters.
  autoCloseSeconds: 300,
};
