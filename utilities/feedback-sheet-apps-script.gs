/**
 * Apps Script for the response Sheet of the "BJC Teacher Guide Feedback"
 * Google Form, which the Teacher Guide "Feedback" button posts to (see
 * llab.FEEDBACK_FORM in llab/loader.js).
 *
 * For each new response it:
 *  - adds a "GitHub Issue" link in that row, which opens a pre-filled
 *    "New issue" page (you review it and click Create), and
 *  - emails the response, with the same link, to everyone listed on the
 *    Data tab.
 * It also adds a "Feedback" menu to make the issue link for any row.
 *
 * Settings come from the "Data" tab, row 1 being headers:
 *   EMAIL DESTINATIONS  one address per row
 *   GITHUB URL          the repository, e.g. https://github.com/bjc-edc/bjc-r
 *   GITHUB LABELS       optional, one label per row; without this column,
 *                       issues get DEFAULT_LABELS
 *   GITHUB PROJECT      optional, a project to add the issue to, as
 *                       <org>/<number>, e.g. bjc-edc/1
 * GitHub only applies labels and projects when the person clicking Create
 * can triage the repository; otherwise it quietly leaves them off.
 *
 * This runs in Google Apps Script, not on the site. To install:
 *  1. In the response Sheet: Extensions > Apps Script.
 *  2. Replace the contents of Code.gs with this file and Save.
 *  3. Pick `installTrigger` in the function menu and click Run once, then
 *     approve the permissions prompt. Re-running it is safe.
 * Emails are sent from the account that ran installTrigger.
 */

const DATA_SHEET = 'Data';
const ISSUE_HEADER = 'GitHub Issue';
const DEFAULT_LABELS = ['teacher feedback'];

// Question titles, which are also the response Sheet's column headers.
const QUESTIONS = {
  about: 'What are you providing feedback about?',
  studentPages: 'Which student lab page(s) are you providing feedback about?',
  comment: 'What can we do to make this content better?',
  email: 'Email (optional)',
  page: 'Page title',
  url: 'Page URL',
  topic: 'Topic file',
  course: 'Course file',
};

// GitHub rejects longer "new issue" links; the comment is trimmed to fit.
const MAX_ISSUE_URL_LENGTH = 7000;

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Feedback')
    .addItem('Create GitHub issue for selected row', 'createIssueForSelectedRow')
    .addItem('Add missing GitHub issue links', 'addMissingIssueLinks')
    .addSeparator()
    .addItem('Install new-response trigger', 'installTrigger')
    .addToUi();
}

function installTrigger() {
  ScriptApp.getProjectTriggers()
    .filter(trigger => trigger.getHandlerFunction() === 'onFeedbackSubmitted')
    .forEach(trigger => ScriptApp.deleteTrigger(trigger));
  ScriptApp.newTrigger('onFeedbackSubmitted')
    .forSpreadsheet(SpreadsheetApp.getActive())
    .onFormSubmit()
    .create();
}

// Runs for each new form response.
function onFeedbackSubmitted(event) {
  const sheet = event.range.getSheet(),
    row = event.range.getRow(),
    settings = readSettings(),
    response = readResponse(sheet, row),
    issueURL = newIssueURL(response, settings);
  setIssueLink(sheet, row, issueURL);
  emailResponse(response, issueURL, settings.emails);
}

/////////////////////////////// Menu actions

function createIssueForSelectedRow() {
  const sheet = SpreadsheetApp.getActiveSheet(),
    row = sheet.getActiveRange().getRow(),
    ui = SpreadsheetApp.getUi();
  if (!isResponseSheet(sheet) || row < 2) {
    ui.alert('Select a cell in a response row on the form responses tab first.');
    return;
  }
  const issueURL = newIssueURL(readResponse(sheet, row), readSettings());
  setIssueLink(sheet, row, issueURL);
  // Apps Script can't open a tab itself; try from the dialog, with a link
  // as the fallback when the browser blocks the pop-up.
  const html = HtmlService.createHtmlOutput(
    `<p><a href="${escapeHTML(issueURL)}" target="_blank" rel="noopener">` +
    `Open the new GitHub issue for row ${row}</a></p>` +
    `<p style="color:#666">Review it on GitHub, then click "Create".</p>` +
    `<script>if (window.open(${JSON.stringify(issueURL)}, '_blank')) {` +
    ` google.script.host.close(); }</script>`
  ).setWidth(360).setHeight(110);
  ui.showModalDialog(html, 'Create GitHub issue');
}

// For responses that arrived before the trigger was installed.
function addMissingIssueLinks() {
  const sheet = SpreadsheetApp.getActiveSheet();
  if (!isResponseSheet(sheet)) {
    SpreadsheetApp.getUi().alert('Switch to the form responses tab first.');
    return;
  }
  const settings = readSettings(),
    column = issueColumn(sheet),
    lastRow = sheet.getLastRow();
  if (lastRow < 2) { return; }
  const existing = sheet.getRange(2, column, lastRow - 1, 1).getValues();
  existing.forEach(([value], index) => {
    if (value === '') {
      const row = index + 2;
      setIssueLink(sheet, row, newIssueURL(readResponse(sheet, row), settings));
    }
  });
}

/////////////////////////////// Sheet helpers

function readSettings() {
  const sheet = SpreadsheetApp.getActive().getSheetByName(DATA_SHEET);
  if (!sheet) { throw new Error(`There is no "${DATA_SHEET}" tab.`); }
  const [header, ...rows] = sheet.getDataRange().getDisplayValues(),
    names = header.map(name => name.trim().toUpperCase()),
    // null when there is no such column.
    columnValues = name => {
      const column = names.indexOf(name);
      return column < 0 ? null :
        rows.map(row => row[column].trim()).filter(Boolean);
    };
  const emails = columnValues('EMAIL DESTINATIONS') || [],
    github = (columnValues('GITHUB URL') || [])[0],
    labels = columnValues('GITHUB LABELS') || DEFAULT_LABELS,
    project = (columnValues('GITHUB PROJECT') || [])[0] || '';
  if (!github) { throw new Error(`Add a GITHUB URL on the "${DATA_SHEET}" tab.`); }
  return { emails, github: github.replace(/\/+$/, ''), labels, project };
}

function headers(sheet) {
  return sheet.getRange(1, 1, 1, sheet.getLastColumn()).getDisplayValues()[0]
    .map(header => header.trim());
}

function isResponseSheet(sheet) {
  return headers(sheet).includes(QUESTIONS.comment);
}

// The row as { header: displayed value }.
function readResponse(sheet, row) {
  const names = headers(sheet),
    values = sheet.getRange(row, 1, 1, names.length).getDisplayValues()[0],
    response = {};
  names.forEach((name, index) => { response[name] = values[index].trim(); });
  return response;
}

function issueColumn(sheet) {
  const names = headers(sheet),
    index = names.indexOf(ISSUE_HEADER);
  if (index >= 0) { return index + 1; }
  const column = names.length + 1;
  sheet.getRange(1, column).setValue(ISSUE_HEADER).setFontWeight('bold');
  return column;
}

// A rich-text link rather than =HYPERLINK(): no formula length limit or quoting.
function setIssueLink(sheet, row, issueURL) {
  sheet.getRange(row, issueColumn(sheet)).setRichTextValue(
    SpreadsheetApp.newRichTextValue()
      .setText('Create issue')
      .setLinkUrl(issueURL)
      .build()
  );
}

/////////////////////////////// Issue + email content

function newIssueURL(response, { github, labels, project }) {
  const get = key => response[QUESTIONS[key]] || '',
    page = get('page') || 'unknown page',
    comment = get('comment'),
    summary = comment.replace(/\s+/g, ' ');
  const title = `Teacher feedback: ${page}` + (summary ?
    ` - ${summary.length > 60 ? summary.slice(0, 60) + '…' : summary}` : '');

  const issueURL = commentText => {
    const about = get('about') + (get('studentPages') ? ` (${get('studentPages')})` : '');
    // The teacher's email stays in the Sheet; issues are public.
    const body = [
      `**Page:** ${get('url') ? `[${markdownText(page)}](${markdownURL(get('url'))})` : markdownText(page)}`,
      about ? `**About:** ${markdownText(about)}` : null,
      get('course') ? `**Course:** \`${get('course')}\`` : null,
      get('topic') ? `**Topic:** \`${get('topic')}\`` : null,
      response.Timestamp ? `**Submitted:** ${response.Timestamp}` : null,
      '',
      '### Feedback',
      '',
      quote(commentText || '(no comment)'),
      '',
      '_From the Teacher Guide feedback form._',
    ].filter(line => line !== null).join('\n');
    return `${github}/issues/new?title=${encodeURIComponent(title)}` +
      `&body=${encodeURIComponent(body)}` +
      (labels.length ? `&labels=${encodeURIComponent(labels.join(','))}` : '') +
      (project ? `&projects=${encodeURIComponent(project)}` : '');
  };

  let text = comment, url = issueURL(text);
  while (url.length > MAX_ISSUE_URL_LENGTH && text.length > 0) {
    text = text.slice(0, Math.floor(text.length * 0.8));
    url = issueURL(text + '\n\n[Trimmed; see the full response in the feedback Sheet.]');
  }
  return url;
}

// Block-quote the teacher's text as plain text: "<" can't start HTML, and a
// zero-width space after "@" keeps "@name" from notifying a GitHub user.
function quote(text) {
  return text.replace(/</g, '&lt;').replace(/@(?=\w)/g, '@\u200B')
    .split('\n').map(line => `> ${line}`).join('\n');
}

// Percent-encode what would end a Markdown link's (url) early.
function markdownURL(url) {
  return url.replace(/[()\s]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase().padStart(2, '0'));
}

function markdownText(text) {
  return text.replace(/([\\[\]*_`<>])/g, '\\$1').replace(/@(?=\w)/g, '@\u200B');
}

function escapeHTML(text) {
  return String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function emailResponse(response, issueURL, recipients) {
  if (recipients.length === 0) { return; }
  const get = key => response[QUESTIONS[key]] || '',
    answered = Object.values(QUESTIONS).filter(question => response[question]),
    sheetURL = SpreadsheetApp.getActive().getUrl(),
    email = get('email');

  const text = answered.map(question => `${question}\n${response[question]}`)
    .join('\n\n') +
    `\n\nCreate a GitHub issue: ${issueURL}\nAll responses: ${sheetURL}`;
  const html = answered.map(question =>
      `<p><b>${escapeHTML(question)}</b><br>` +
      `${escapeHTML(response[question]).replace(/\n/g, '<br>')}</p>`
    ).join('') +
    `<p><a href="${escapeHTML(issueURL)}">Create a GitHub issue</a> · ` +
    `<a href="${escapeHTML(sheetURL)}">All responses</a></p>`;

  const options = { name: 'BJC Teacher Guide Feedback', htmlBody: html };
  // So "Reply" goes to the teacher, when they left a usable address.
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { options.replyTo = email; }
  MailApp.sendEmail(recipients.join(','),
    `BJC feedback: ${get('page') || 'unknown page'}`, text, options);
}
