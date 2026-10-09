function w=fusiReferenceTraceWindow(r,wholeScan)
% Display reference before current t=0; preserve source times separately.
frames=r.frames;if wholeScan,frames=[1 r.nFrames];end
shift=-frames(2)*r.TR;
w=struct('shiftSec',shift,'plotWindowSec',(frames-1)*r.TR+shift, ...
    'baselinePlotSec',r.windowSec+shift,'sourceWindowSec',(frames-1)*r.TR);
end
