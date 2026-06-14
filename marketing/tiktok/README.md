# Hotblock TikTok Sprint

This folder is the operating system for a 30-day organic TikTok sprint starting
Monday, June 15, 2026. The objective is to publish 20 useful experiments, find
two repeatable formats, and measure whether TikTok traffic turns into Hotblock
downloads.

## Account Setup

- Profile name: `Hotblock`
- Bio: `A strict Mac blocker that closes distractions and talks back. Free: hotblock.app`
- Website URL for week one: `https://hotblock.app/?utm_source=tiktok&utm_medium=organic&utm_campaign=week_1`
- Spoken CTA: `Open hotblock.app on your Mac`
- Final-frame CTA: `Free for Mac · hotblock.app`
- Pin after week one: strongest product demo, founder story, and strict-mode explanation

Change the campaign value to `week_2`, `week_3`, and `week_4` each Monday. Keep
the visible and spoken URL simple: `hotblock.app`.

## Files

- `content-calendar.csv`: posting schedule, creative hypothesis, and status
- `scripts.md`: ready-to-film scripts and captions for all 20 posts
- `metrics.csv`: experiment tracker populated after 2 and 48 hours
- `recording-checklist.md`: weekly batch-production and quality checklist
- `assets/final-card.svg`: reusable final CTA frame
- `assets/safe-zone-overlay.svg`: overlay to keep text clear of TikTok controls

## Weekly Workflow

1. Review the previous week's results and identify the top two hooks.
2. Batch record five posts in one 90-minute session.
3. Edit with large burned-in captions and the reusable final card.
4. Publish one post each weekday at the scheduled Stockholm time.
5. Spend 20 to 30 minutes replying to comments after publishing.
6. Turn strong questions into reply videos within 24 hours.
7. Fill in `metrics.csv` after 2 hours and again after 48 hours.
8. Recut the top 20% of concepts with a new opening within 72 hours.

## Decision Rules

- Rewrite a format if its 48-hour views are below 70% of the account median.
- Create a sequel when a post exceeds 1.5 times the median for views, shares,
  profile visits, or download clicks.
- Optimize for downloads per 1,000 views and download-click rate, not views alone.
- Treat download questions and platform requests as high-intent comments.
- Do not claim Hotblock is impossible to quit or uninstall.
- Do not make medical or ADHD treatment claims.

## Plausible Setup

The site includes privacy-friendly Plausible tracking for `hotblock.app` and
sends these custom events:

- `Download`: a desktop visitor clicks a DMG download button
- `Mobile Download Intent`: a phone visitor clicks download and is told to open the site on a Mac
- `Copy Mac URL`: a phone visitor copies `hotblock.app`
- `Release View`: a visitor opens the GitHub release page

Create `hotblock.app` in Plausible Hosted, then add the four matching custom
event goals. Verify each event in the browser network panel and in Plausible
before the first post goes live.

Plausible automatically reads the weekly UTM parameters. Filter the dashboard
by `utm_source=tiktok` and compare each weekly campaign.

## Sprint Success Criteria

- Publish all 20 videos.
- Identify at least two repeatable formats.
- Produce at least three posts above twice the account median.
- Measure TikTok-attributed site visits and download events.
- Improve downloads per 1,000 views by week four.
