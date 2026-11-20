# Firestore Read Cost & Query Audit

| Query / Flow | Old Reads (Listeners / Bounded) | New Reads (One-time / Cached) | Optimization |
| :--- | :--- | :--- | :--- |
| Home Active Jobs | N updates × limit docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Home Technical Roles | N updates × 30 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Home Non-Technical | N updates × 30 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Home Fresher Jobs | N updates × 30 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Home Near Location | N updates × 30 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Verified Companies | N updates × 10 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Active Categories | N updates × all categories | Cat count once / session | Cached in memory (keepAlive provider) |
| Category Counts | Uncached reads per screen | 1 doc once / session | Cached in memory (keepAlive provider) |
| Recommendations Top | N updates × 10 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Skill Matches | N updates × 10 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Education Matches | N updates × 10 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Location Matches | N updates × 10 docs (Stream) | 10 docs once | One-time get(), limit(10), autoDispose |
| Company By ID | Persistent snapshot listener | 1 doc once | One-time get() |
| Job List Pagination | 20 docs / page | 20 docs / page | startAfter cursor pagination |

### Retained Real-Time Listeners
- Resume upload & parsing status (`watchResume`, `watchResumeParse`)
- User notifications unread count & saved job status (where configured)
