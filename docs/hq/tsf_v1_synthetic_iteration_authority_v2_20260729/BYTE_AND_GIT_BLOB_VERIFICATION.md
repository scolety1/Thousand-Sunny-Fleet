# Byte and Git Blob Verification

The canonical approved replacement SHA is rechecked over exact bytes at every
security boundary:

1. controlled Builder artifact;
2. before-file state;
3. durable temporary file;
4. file immediately after atomic replacement;
5. immediately before and after every syntax, focused, and acceptance command;
6. before commit authority;
7. immediately before staging;
8. raw staged Git blob;
9. working tree immediately before commit;
10. raw committed Git blob;
11. working tree immediately after commit;
12. postcommit verifier observation;
13. canonical admission observation.

The Git runner uses its pinned absolute executable and a closed environment.
Staged and committed blob content is read as raw bytes, not decoded command
text. The proof records Git object ID, mode, byte length, and SHA-256. The
staged blob, committed blob, and canonical candidate must all match.

A mismatch stops before the next boundary. Passing tests cannot authorize
different bytes.
