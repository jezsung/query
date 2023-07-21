## 0.3.7 (2023-07-21)

- Fix: `useQuery` schedules cache removal after `gcDuration` when key is changed

## 0.3.6 (2023-07-21)

- `useImperativeQuery`'s `fetch` refetches when called with same key

## 0.3.5 (2023-07-20)

- Fixed `refetchOnResumed` issue on `useImperativeQuery`
- Added `gcDuration` to `usePagedQuery`
- Removed intermittent `QueryStatus.idle`

## 0.3.4 (2023-07-19)

- Inactive cached query will be removed after the `gcDuration`

## 0.3.3 (2023-07-17)

- Add `useImperativeQuery` hook

## 0.3.2 (2023-07-17)

- Make query key generic type

## 0.3.1 (2023-07-15)

- Fix refetching on resumed when enabled is false

## 0.3.0 (2023-07-12)

- Dropped widget-based API
- Supports hook-based API

## 0.2.0 (2023-05-31)

- Initial release. Prior to this version of the unfinished code will not be maintained.

## <0.1.19

- The unfinished code will not be maintained.
