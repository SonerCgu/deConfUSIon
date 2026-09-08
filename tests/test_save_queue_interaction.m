function test_save_queue_interaction()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
work=tempname; mkdir(work);
f=figure('Visible','off'); guard=onCleanup(@()delete(f)); %#ok<NASGU>
setappdata(f,'deConfUSIonInteractionUntil',now+10/86400);
I=single(randn(50,51,4,100));
D=struct('I',I,'TR',.385,'PSC',I*2,'bg',ones(50,51,4), ...
    'deconfPscKey',[20 40 .385 100 1],'motorInfo',struct('nSlices',4));
path=fullfile(work,'saved.mat'); DataIO('enqueue',path,struct('newData',D));
DataIO('poll'); pause(.3);
assert(strcmp(DataIO('status',path),'queued') && ~isfile(path),'Saving blocked viewer interaction.');
setappdata(f,'deConfUSIonInteractionUntil',0);
DataIO('wait'); S=load(path);
assert(isequal(S.newData.I,I) && S.newData.TR==D.TR && isequal(S.newData.motorInfo,D.motorInfo));
assert(~isfield(S.newData,'PSC') && ~isfield(S.newData,'deconfPscKey'));
assert(isfield(D,'PSC'),'Source in-memory dataset was altered.');
% Unmarked scientific fields are not treated as a disposable viewer cache.
path2=fullfile(work,'noncache.mat'); D=rmfield(D,'deconfPscKey');
DataIO('enqueue',path2,struct('newData',D)); DataIO('wait'); S=load(path2);
assert(isequal(S.newData.PSC,D.PSC));
fprintf('PASS save queue yields to viewer activity, resumes atomically and preserves data.\n');
end
