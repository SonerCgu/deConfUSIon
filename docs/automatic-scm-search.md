# Automatic SCM: spatial and plateau search

Close and reopen SCM after updating MATLAB files; an already-open GUI keeps its
old callbacks. Open **Automatic analysis > Find and review ROI**.

1. Set the baseline in SCM. In the black search dialog, enter **Search start/end**
   in minutes, for example `5 15`.
2. Set **Plateau duration** to `2` to search all consecutive two-minute windows
   between minutes 5 and 15. Set `0` to average the entire selected interval.
   The search jointly selects the square ROI and time window with the highest
   mean rebased PSC. Choose **Different best window per ROI / slice** or
   **Same best window across all slices** (default). Shared mode finds the globally
   strongest eligible candidate window, then re-searches Target and Control on
   every requested slice using that exact common window.
3. Choose square ROI side length in pixels. Enter **X start/end, Y start/end**,
   or click **Draw rectangle**, press and drag on the image, then release.
   A live outline follows the pointer. Escape cancels drawing; Reset restores
   the whole image. This rectangle applies to every searched slice.
4. Enable **Separate left/right target and control** and choose **LEFT = Target**
   or **RIGHT = Target**. The opposite side automatically becomes Control.
   The preview labels both regions. Move the numeric X boundary if required.
   Left/right refer to the displayed image, not inferred anatomical orientation.
5. Scroll the mouse wheel or use the slider to preview other slices. Select
   **Search all slices**, or uncheck it to search only the previewed slice.
6. Click **GO / Start analysis**. Invalid settings are explained directly above
   the button. A progress window appears during analysis, including single-slice
   searches. Cancel preserves existing marks. A successful rerun replaces unsaved
   automatic candidates instead of accumulating them; numbering restarts at 1
   when no other marks remain. Manual and already-exported marks are retained.
7. The highest-response slice opens automatically. Filter the review table by
   Target/Control and slice range (or one slice); sort by maximum/minimum PSC or
   ascending/descending slice. **Show maximum** opens the strongest filtered result.
   Selecting a row switches SCM to its slice and window. In shared mode this
   interval remains identical across slices. Table rows and marks turn red for
   any slice with a candidate window-mean PSC >200%. This flags it for review,
   without excluding it. Otherwise orange identifies Target, blue identifies
   Control. Regions without a fully valid ROI/window are reported explicitly.
8. Tick the **Export** column and use **Export SELECTED ROIs (TXT)** for checked candidates.
   The main SCM **EXPORT ROIs (TXT)** button exports all marks, including manual marks.
   **Choose Target + Control to export** asks for exactly one marked ROI per role
   and writes only those two traces, labeled Target and Ctrl, to the normal ROI
   folder. Table filters do not restrict the all-marks export.
   **Clear ALL marked ROIs** removes marks across every slice and closes the
   summary and resets marker numbering to 1; exported files remain. This button
   is also in the main SCM panel. Marker IDs are separate from export-set numbers.

Automatic selection metadata records the search interval, requested plateau
duration, selected frames, actual time span, spatial constraints and roles.
Independent mode can select different intervals for each side. Shared mode uses
one interval chosen from the data; an independently prespecified interval is
still preferable for confirmatory target/control comparisons.

“Plateau” means the highest **window-averaged positive PSC**, not a flatness test
or the largest absolute change. A sufficiently large short spike can still
influence the average. In a negative-only region the least negative candidate
wins. Spatial and temporal maximization remain exploratory and upward-biased;
use independent/held-out data or **Load fixed protocol** for confirmatory analysis.

Plateau windows use acquired frames entirely within the search interval. Their
sample-to-sample duration rounds UP to the next multiple of TR, includes both
endpoints and is at least the requested duration. For example, 60 seconds at
TR = 33.5 seconds uses three samples spanning 67 seconds. With duration 0,
SCM's original nearest-frame, inclusive-endpoint averaging is retained.

The existing inclusion mask, rectangle and side mask are intersected. A complete
square ROI must fit in that intersection and have finite data throughout baseline
and the selected window. Display smoothing/alpha/thresholds do not affect scores.
The same workflow operates on the current 2D, motor-acquired 2D or 3D SCM array.
Source data are not modified. Dialog settings start fresh for each search.

Run the synthetic tests from MATLAB:

```matlab
results = runtests('tests/testAutomaticSCM.m');
assert(all([results.Passed]));
```

### Selecting exports and controlling hover

In the candidate table, tick **Export** for each desired ROI, then use
**Export SELECTED ROIs (TXT)**. Green highlighting identifies selected rows;
red text still flags slices exceeding 200%. Selections survive sorting and
filtering, including currently hidden rows, and the status shows their count.
Only checked ROIs are written, with each candidate's Target/Control label and
signal window. The main SCM **EXPORT ROIs (TXT)** button retains its all-marks
export behavior; the explicit Target + Control pair picker is also available.

**HOVER ACTIVE** (green) enables the moving preview. Click to switch to
**HOVER INACTIVE** (red); pending previews are cancelled and moving the mouse
or changing slices cannot re-enable it. Click again to reactivate. Selecting
an automatic candidate or placing a fixed ROI also switches hover to inactive.
