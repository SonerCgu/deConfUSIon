function [out,context]=scmCompactROIAudit(candidates,folder,context)
% Preserve full external baselines once in MAT, with portable JSON links.
% Runtime candidates remain unchanged; only their exported audit is compact.
if nargin<3||isempty(context),context=struct('references',{{}},'files',{{}});end
out=candidates;
if iscell(candidates)
    for k=1:numel(candidates),[out{k},context]=scmCompactROIAudit(candidates{k},folder,context);end
    return;
end
if isfield(out,'searchTrace')
    out.searchTraceSamples=numel(out.searchTrace);
    out.searchTraceStorage='Source PSC curve is written in the ROI TXT data columns.';
    out=rmfield(out,'searchTrace');
end
if ~isfield(out,'baselineReference')||~isstruct(out.baselineReference),return;end
ref=out.baselineReference;
% File-backed references can retain a 32 MB raw movie preview for interactive
% plotting. It is not needed to reproduce exported PSC. Keep the exact mean
% and source/window provenance; avoid copying that preview for every export.
fileBacked=isfield(ref,'sourceFile')&&~isempty(ref.sourceFile);
if fileBacked&&isfield(ref,'tracePower')
    remove=intersect({'tracePower','traceFrames'},fieldnames(ref),'stable');
    ref=rmfield(ref,remove);
    ref.previewStorage='Optional interactive raw preview omitted; exact baseline mean preserved in payloadFile. Original frames are identified by sourceFile, TR and frames.';
end
payloadFields=intersect({'mean','tracePower'},fieldnames(ref),'stable');
if isempty(payloadFields),return;end
hit=[];
for k=1:numel(context.references)
    if isequaln(ref,context.references{k}),hit=k;break;end
end
if isempty(hit)
    % A UUID here consumed another 40 characters on deep Windows paths.
    number=numel(context.files)+1;name=sprintf('BaselineReference_%02d.mat',number);
    while exist(fullfile(folder,name),'file') || exist(fullfile(folder,[name '.part']),'file')
        number=number+1;name=sprintf('BaselineReference_%02d.mat',number);
    end
    destination=fullfile(folder,name);
    % These bounded baseline means / previews fit in a classic MAT file.
    % Stage locally, then transfer the completed file sequentially.
    temporary=[tempname '.mat'];partial=[destination '.part'];
    cleanup=onCleanup(@()cleanupAuditFiles(temporary,partial)); %#ok<NASGU>
    baselineReference=ref; %#ok<NASGU>
    try
        payloadInfo=whos('baselineReference');
        if payloadInfo.bytes<1.5*1024^3,save(temporary,'baselineReference','-v7');
        else,save(temporary,'baselineReference','-v7.3','-nocompression');end
    catch ME
        failure=MException('deConfUSIon:ROIAudit', ...
            'Could not stage baseline reference in %s: %s',temporary,ME.message);
        failure=addCause(failure,ME);throw(failure);
    end
    info=whos('-file',temporary);
    assert(any(strcmp({info.name},'baselineReference')),'deConfUSIon:ROIAudit','Incomplete baseline audit: %s',temporary);
    [ok,message]=copyfile(temporary,partial);
    assert(ok,'deConfUSIon:ROIAudit','Could not copy baseline audit to %s: %s',partial,message);
    localInfo=dir(temporary);remoteInfo=dir(partial);
    assert(~isempty(remoteInfo)&&remoteInfo.bytes==localInfo.bytes, ...
        'deConfUSIon:ROIAudit','Incomplete baseline audit transfer to %s.',partial);
    [ok,message]=movefile(partial,destination);
    assert(ok,'deConfUSIon:ROIAudit','Could not publish baseline audit %s: %s',destination,message);
    context.references{end+1}=ref;context.files{end+1}=name;hit=numel(context.files);
end
ref=rmfield(ref,payloadFields);
ref.payloadFile=context.files{hit};ref.payloadVariable='baselineReference';
ref.payloadFields=payloadFields;
ref.storage='Full reference in adjacent MAT file; path is relative to this ROI TXT. Keep the export folder together.';
out.baselineReference=ref;
end

function cleanupAuditFiles(varargin)
% Only remove this operation's staging files, never a published MAT.
for k=1:nargin
    if isfile(varargin{k}),try,delete(varargin{k});catch,end,end
end
end
