# NutritionApp HRV Release Plan

Status date: 8 June 2026

## Where we are now

The HRV module is built, committed to `main`, and the full test suite (now 72 plus tests, including the PPG signal tests) passes on the iPhone 17 simulator. The real camera PPG capture is implemented behind a clean provider seam, so the headline feature now uses the rear camera with the torch on, with the simulated provider kept for the simulator and for automated tests.

This is a code milestone, not a shipped product. No build has been distributed.

## The one thing that blocks any release

The project is signed with a Personal Team, which cannot distribute through TestFlight or the App Store. Tobias has a paid Apple Developer Program account, so the release track runs through his account. Until the app is registered under that account and signing is fixed, nothing can be uploaded to Apple.

## Step by step, with owner and rough effort

1. Add the app to Tobias's Apple Developer account. Register the App ID `com.markolukic.NutritionApp` (or a new bundle id under his team) and create the app record in App Store Connect. Owner: Tobias. Effort: about 30 minutes.

2. Fix signing in Xcode: select Tobias's team, let Xcode manage the provisioning profile, confirm the two signing errors clear. Owner: Tobias, or Marko on a machine logged into that team. I can guide this on screen. Effort: about 15 minutes once the account exists.

3. Decide the bundle identifier and display name finally, so they match App Store Connect. Owner: Marko and Tobias. Effort: a quick decision.

4. Set the version (for example 1.0.0) and a build number, then Product, Archive on a real iPhone. Owner: Tobias or Marko. Effort: about 15 minutes plus build time.

5. Upload the archive to App Store Connect from the Xcode Organizer, then distribute the build to TestFlight and add internal testers. Owner: Tobias. Effort: about 30 minutes, plus Apple processing time.

6. For a public App Store release, prepare metadata, screenshots, a privacy policy URL, and the App Privacy answers. HealthKit and camera health use get extra scrutiny in App Review, so the privacy text and the usage descriptions must be accurate. Owner: Marko for the content, Tobias for the submission. Effort: half a day, plus Apple review time of roughly one to three days.

## Product items to finish before we call it done

These do not block a TestFlight beta, but they matter for a real release.

1. Device test of the camera PPG scan. It cannot run in the simulator, so it needs a real device with a finger on the lens. I can support this once a signed build is on a device. Owner: Marko to test, me to fix anything that shows up.

2. The 22 of 27 metric glossary texts that are not yet translated to English and German. Owner: me. Effort: a few hours.

3. Optional: tune the PPG peak detection against real recordings once we have device data. Owner: me, after device testing.

## What I can do without anyone

Finish the metric translations, refine the PPG processing, and fix any compile or test issues. These are pure code tasks and need no account.

## Summary of ownership

- Tobias: Apple Developer account, signing, App Store Connect, TestFlight, App Store submission.
- Marko: final naming decision, device testing of the scan, metadata and privacy content.
- Me (in the agent): remaining translations, PPG refinement, code fixes, and on screen guidance through the Xcode steps.
