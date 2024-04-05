#  iCloud storage POC

This POC is about investigating the possibility of using iCloud containers to backup the Profile.
The findings are that we can make use efficiently of iCloud contains for backing up the Profile.

# Key findings

- iCloud container is tied to the user's iCloud account.
- No user facing autentication is required to perform operations on the iCloud container.
- We can reliably check if the app has access to the iCloud container.
- Disabling iCloud sync does not remove the backup.
- We can easily query for all of the backed up profiles, no need for some metadata representations.
- Profile is uploaded as CKAsset, which can hold large files.

- Each Profile is represented by a CKRecord of type Profile, identified by the profile id.
- We can fetch all user profiles by fetching CKRecords with type Profile.
- Each record has a last modification date, representing the timestamp of the last upload.

