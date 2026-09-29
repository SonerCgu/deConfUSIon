function [window,ok,note]=scmAwakeSearchWindow(TR,nT)
% Never shorten the requested three-minute plateau to fit a short recording.
window=[240 min(960,(nT-1)*TR)]; ok=false;
note='Awake search skipped: no complete 3-minute plateau fits after minute 4.';
if window(2)<=window(1), return; end
try
    scmSearchWindows(window,180,TR,nT); ok=true;
    note=sprintf('Awake search: %.3g-%.3g min, 3-minute plateau, ROI 5 pixels.',window/60);
catch ME
    if ~strcmp(ME.identifier,'deConfUSIon:PlateauWindow'), rethrow(ME); end
end
end
