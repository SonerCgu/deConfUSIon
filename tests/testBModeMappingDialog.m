function testBModeMappingDialog(exampleFile,previewFile,getDoppler)
% Exercise the real mapping dialog, invalid assignments, panel preview and cancel.
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
% Load graphics before a timer can interrupt the first graphics DLL load.
warmup=figure('Visible','off');axes('Parent',warmup);drawnow;delete(warmup);
if nargin<2,previewFile='';end
if nargin<1||isempty(exampleFile)
    source=single(.94*ones(120,160,3));source(2:59,2:79,:)=.2;source(2:59,81:159,:)=.4;
    source(61:119,2:79,:)=.6;source(61:119,81:159,:)=0;shape=[24 32 3];metadata=struct();
    initial=struct('kind','montage','bounds',[1 1 160 120],'rows',2,'cols',2,'trim',1, ...
        'order','row-major','count',3,'sliceIndices',1:3);
else
    shape=[90 64 54];[source,info]=fusiReadBModeUnderlay(exampleFile,shape);metadata=info.metadata;
    initial=fusiBModeMontageLayout(source,shape(3),metadata);
end
if nargin<3,getDoppler=@(z)ones([shape(1:2) 3],'single').*(z/shape(3));end
applied=runDialog('apply',source,shape,metadata,getDoppler,initial,previewFile);
assert(isequal(applied.sliceIndices,initial.sliceIndices));
cancelled=runDialog('cancel',source,shape,metadata,getDoppler,initial,'');assert(isempty(cancelled));
fprintf('PASS: real mapping dialog previews the selected panel, rejects invalid assignments, applies and cancels cleanly.\n');
end

function selection=runDialog(action,source,shape,metadata,getDoppler,initial,previewFile)
audit=containers.Map('KeyType','char','ValueType','any');audit('error')=[];audit('ticks')=0;
t=timer('ExecutionMode','fixedSpacing','Period',.5,'StartDelay',.5,'TimerFcn',@tick);
guard=onCleanup(@()disposeTimer(t));start(t);
selection=fusiBModeMappingDialog(source,shape,metadata,getDoppler,initial);disposeTimer(t);
assert(isempty(findall(0,'Tag','SCM_BModeMappingDialog')),'The dialog was not closed.');
if ~isempty(audit('error')),rethrow(audit('error'));end

    function tick(~,~)
        f=findall(0,'Tag','SCM_BModeMappingDialog');audit('ticks')=audit('ticks')+1;
        if isempty(f),return;end
        try
            assert(audit('ticks')<80,'Timed out waiting for the mapping dialog.');
            if ~isappdata(f,'FUSIBModeMappingReady'),return;end
            if strcmp(action,'cancel'),cancel=get(f,'CloseRequestFcn');cancel(f,[]);return;end
            apply=findobj(f,'Tag','SCM_BModeMappingApply');assert(strcmp(get(apply,'Enable'),'on'));
            assignments=findobj(f,'Tag','SCM_BModeSliceAssignments');set(assignments,'String','1 1');invoke(assignments);
            assert(strcmp(get(apply,'Enable'),'off'),'Invalid slice assignments were accepted.');
            text=strtrim(sprintf('%d ',initial.sliceIndices));
            if numel(initial.sliceIndices)>1&&all(diff(initial.sliceIndices)==1)
                text=sprintf('%d:%d',initial.sliceIndices(1),initial.sliceIndices(end));
            end
            set(assignments,'String',text);invoke(assignments);
            assert(strcmp(get(apply,'Enable'),'on'));
            panel=findobj(f,'Tag','SCM_BModeMappingPanel');k=find(initial.sliceIndices>0,1,'last');
            set(panel,'Value',k);invoke(panel);ax=findobj(f,'Tag','SCM_BModeDopplerPreview');
            assert(strcmp(ax.Title.String,sprintf('Doppler slice %d',initial.sliceIndices(k))));
            assert(strcmp(ax.YDir,'reverse'),'The preview flipped the image vertically.');
            set(panel,'Value',1);invoke(panel);drawnow;
            if ~isempty(previewFile),frame=getframe(f);imwrite(frame.cdata,previewFile);end
            invoke(apply);
        catch ME
            audit('error')=ME;cancel=get(f,'CloseRequestFcn');cancel(f,[]);
        end
    end
end

function invoke(h)
callback=get(h,'Callback');callback(h,[]);
end

function disposeTimer(t)
if isvalid(t),stop(t);delete(t);end
end
