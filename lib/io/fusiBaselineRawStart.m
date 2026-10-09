function path=fusiBaselineRawStart(par,fallback)
% Start in the current animal's raw recording folder, never AnalysedData.
path=fallback;
for field={'loadedFile','rawPath','loadedPath'}
    if isfield(par,field{1})&&~isempty(par.(field{1}))
        candidate=char(par.(field{1}));if isfile(candidate),candidate=fileparts(candidate);end
        if isfolder(candidate)&&contains(strrep(candidate,'\','/'),'/RawData','IgnoreCase',true),path=candidate;return;end
    end
end
normalized=strrep(fallback,'\','/');cut=regexp(normalized,'/AnalysedData(?=/|$)','end','once','ignorecase');
if ~isempty(cut)
    candidate=regexprep(normalized(1:cut),'AnalysedData$','RawData','ignorecase');
    if isfolder(candidate),path=candidate;end
end
end
