function [tc,time,sourceTR,sourceLabel]=scmCandidateExportTrace(A,TR,c)
% A scan-search candidate is measured/exported on its own acquisition grid.
sourceTR=TR;sourceLabel='';
if isfield(c,'searchScanKey')
    assert(~isfield(c,'searchTraceValid')||c.searchTraceValid, ...
        'deConfUSIon:ROISearchSource','The baseline changed after this multi-scan search. Repeat Automatic analysis before exporting.');
    assert(isfield(c,'searchTrace')&&isnumeric(c.searchTrace)&&~isempty(c.searchTrace), ...
        'deConfUSIon:ROISearchSource','This multi-scan ROI has no saved source curve. Repeat Automatic analysis before exporting.');
    tc=double(c.searchTrace(:));sourceTR=c.searchTR;sourceLabel=c.searchScanLabel;
else
    tc=scmROI('trace',A,c);tc=tc(:);
end
assert(isscalar(sourceTR)&&isfinite(sourceTR)&&sourceTR>0,'deConfUSIon:ROISearchSource','Invalid source scan timing.');
time=(0:numel(tc)-1)'*sourceTR;
end
