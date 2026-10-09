function P=fusiResolveAnalysisFolder(rawFile)
% One shared RawData -> AnalysedData mapping for Studio and baseline selection.
[folder,name,ext]=fileparts(char(rawFile));
if strcmpi(ext,'.gz')&&endsWith(name,'.nii','IgnoreCase',true),name=name(1:end-4);end
name=regexprep(name,'[^\w\-]+','_');name=regexprep(name,'_+','_');
name=regexprep(name,'^_+|_+$','');if isempty(name),name='item';end
normalized=strrep(folder,'\','/');
cut=regexp(normalized,'(^|/)RawData(?=/|$)','end','once','ignorecase');
if isempty(cut)
    rawRoot=folder;analysisRoot=fullfile(folder,'AnalysedData');relative='';
else
    rawRoot=strrep(normalized(1:cut),'/',filesep);
    analysisRoot=regexprep(rawRoot,'RawData$','AnalysedData','ignorecase');
    relative=regexprep(normalized(cut+1:end),'^/+','');
    relative=strrep(relative,'/',filesep);
end
expected=fullfile(analysisRoot,relative,name);selected=expected;
% Reuse legacy flat results after raw files have been moved into an animal
% folder. An empty folder made by an earlier load must not hide those results.
legacy=fullfile(analysisRoot,name);
if ~strcmpi(expected,legacy)&&~hasDatasets(expected)&&hasDatasets(legacy)
    selected=legacy;
end
P=struct('rawRoot',rawRoot,'analysedRoot',analysisRoot,'datasetName',name, ...
    'expectedFolder',expected,'datasetFolder',selected,'usedLegacyFolder',~strcmpi(selected,expected));
end
function yes=hasDatasets(folder)
yes=false;if ~isfolder(folder),return;end
for part={'Preprocessing','P','PSC',fullfile('PSC','P')}
    files=dir(fullfile(folder,part{1},'*.mat'));
    if any([files.bytes]>0),yes=true;return;end
end
end
