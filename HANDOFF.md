# 🔁 המשך עבודה — קובץ העברה ל-Claude Code (מחשב שני)

> **למשתמש:** פתח את Claude Code בתוך תיקיית `propmanager` במחשב החדש,
> וכתוב לו: **"קרא את HANDOFF.md ותמשיך מאיפה שעצרנו."**
>
> **ל-Claude Code:** זהו brief העברה. קרא אותו במלואו, ואז המשך את תהליך
> ההעלאה לאוויר (deploy) מהנקודה המסומנת ב"מה נשאר לעשות". כל ההחלטות כבר
> התקבלו — אל תתחיל מחדש, פשוט המשך.

---

## מה זה הפרויקט
**PropManager** — אפליקציית ניהול נכסים להשכרה (נכסים, דיירים, תשלומים,
הוצאות, תחזוקה, יומן, מסמכים, פורטל דייר, ועוזר AI).

- **מבנה:** קובץ סטטי בודד — `index.html` (כל ה-HTML/CSS/JS בפנים).
- **Backend:** Supabase — מסד נתונים (`app_data`), אימות (אימייל + Google OAuth),
  ואחסון קבצים (bucket בשם `tenant-docs`).
- **Supabase project ref:** `mzfyhlgzvusbpbeaznrh`
- **GitHub repo:** https://github.com/barakn770-cmyk/propmanager (branch `main`)
- **מפתח AI:** כל משתמש מזין מפתח Anthropic משלו ב-Settings; נשמר רק ב-localStorage
  של הדפדפן שלו. לא נשלח לשרת שלנו.
- **הערה:** מפתח ה-anon של Supabase מופיע בקוד — וזה תקין (הוא ציבורי בכוונה).
  **בדיוק בגלל זה RLS הוא חובה** (ראה למטה).

---

## ✅ מה כבר נעשה (אל תחזור על זה)
1. **תוקנו 3 באגים** ב-`index.html` (כבר ב-GitHub, commit `13e90af`):
   - שליחת הודעה לדייר נכשלה בשקט (פתרון: זיהוי דייר לפי אינדקס או שם).
   - חלונות עריכה הדביקו תאריך "היום" אוטומטית והרסו נתונים.
   - תשלום במצב Pending נשמר עם תאריך תשלום שגוי.
2. **נוצר** `supabase-setup.sql` — סקריפט RLS מלא לריבוי משתמשים.
3. **נוצר** `DEPLOY.md` — מדריך העלאה מלא.
4. הכל **נדחף ל-GitHub** ל-branch `main`.

> קובץ מקומי `propmanager-v3.html` הוא עותק זהה ל-`index.html` ונמצא ב-.gitignore.
> אפשר להתעלם ממנו לחלוטין.

---

## 🎯 מה נשאר לעשות — להעלות לאוויר (3 שלבים, לפי הסדר)

### שלב ① — אבטחת Supabase (חובה לפני משתמשים) 🔒
בלי זה כל משתמש שנרשם יכול לקרוא/למחוק את הנתונים של כולם.
1. [Supabase Dashboard](https://supabase.com/dashboard) → הפרויקט (`mzfyhlgzvusbpbeaznrh`)
   → **SQL Editor** → **New query**.
2. הדבק את כל התוכן של `supabase-setup.sql` (בתיקייה הזו) → **Run**.
3. תוצאה תקינה = "Success". שגיאה אדומה → להעתיק ל-Claude Code ולפתור.
   - אם השגיאה היא "could not create unique index"/"duplicate key" → יש שורות
     כפולות ב-`app_data`; צריך למחוק כפילויות ולהריץ שוב.

### שלב ② — אירוח ב-Cloudflare Pages
1. [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages**
   → **Create** → **Pages** → **Connect to Git** → בחר את repo `propmanager`.
2. הגדרות build: **Framework preset = None**, **Build command = ריק**,
   **Build output directory = `/`**.
3. **Save and Deploy** → מקבלים כתובת כמו `https://propmanager-xxx.pages.dev`.
   מעכשיו כל `git push` ל-`main` מעדכן אוטומטית.

### שלב ③ — הפניית ה-Login לכתובת החיה
1. Supabase → **Authentication** → **URL Configuration**.
2. **Site URL** = כתובת ה-pages.dev.
3. **Redirect URLs** → הוסף `https://propmanager-xxx.pages.dev/**`.
   (Google OAuth עצמו לא דורש שינוי.)

### בדיקת קבלה (אסור לדלג)
- שני חשבונות שונים, נכס בכל אחד → לוודא ששום חשבון לא רואה את של השני.
- התחברות עם Google **וגם** אימייל/סיסמה בכתובת החיה.
- העלאת מסמך לדייר ופתיחתו מחדש (בדיקת Storage).

---

## ⚙️ שתי דרכים לבצע (Claude Code — הצע למשתמש לבחור)

**אופציה א' — אוטומטי דרך טוקנים:** המשתמש מפיק שני API tokens, ו-Claude Code
מבצע הכל ב-CLI/API:
- **Supabase Personal Access Token:** https://supabase.com/dashboard/account/tokens
  → משמש להרצת ה-SQL (Management API: `POST /v1/projects/{ref}/database/query`)
  ולהגדרת redirect URLs (`PATCH /v1/projects/{ref}/config/auth`,
  שדות `site_url` ו-`uri_allow_list`).
- **Cloudflare API token (Pages: Edit) + Account ID:** https://dash.cloudflare.com/profile/api-tokens
  → `npx wrangler pages deploy . --project-name=propmanager`.
- 🔒 לבטל את הטוקנים (Revoke) אחרי הסיום.

**אופציה ב' — ליווי ידני:** המשתמש מבצע את הלחיצות בדשבורדים, ו-Claude Code
מלווה שלב-שלב ופותר שגיאות. אין צורך לשתף טוקנים.

---

## כלים שכדאי שיהיו במחשב החדש
- **Git** — לשכפול ול-push.
- **Node/npm** — רק אם בוחרים באופציה א' (בשביל `npx wrangler`). npm כבר נבדק כעובד.

## הקשר אנושי
- המשתמש מעדיף הסברים בעברית.
- ביקש מוקדם יותר ש-Claude "יעשה הכל בעצמו" — אז העדף את אופציה א' (אוטומטי),
  אבל הסבר בכנות שאי אפשר להתחבר לחשבונות הפרטיים בלי טוקנים.

**נקודת המשך:** התחל משלב ① (Supabase SQL).
