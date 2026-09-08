function test_scm_hover()
% Instrument a temporary copy to drive nested callbacks without moving the
% user's desktop pointer. Production callbacks/numerics remain unchanged.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
work=tempname; mkdir(work); addpath(work);
source=fileread(fullfile(root,'SCM_gui.m'));
source=strrep(source,'function fig = SCM_gui(', 'function fig = SCM_hover_fixture(');
marker="set(fig,'DeleteFcn',@disposeHoverTimer);";
hooks="setappdata(fig,'HoverTest',struct('queue',@queueHover,'add',@addRoiAtCenter,'unfreeze',@unfreezeHover,'base',ebBase,'window',@onWindowEdited,'timer',hoverTimer,'rect',hLiveRect,'trace',hLivePSC,'slice',slZ,'sliceChanged',@sliceChanged,'size',slROI,'resize',@setROIsize,'direct',@computeRoiPSC_idx));";
source=strrep(source,marker,marker+newline+hooks);
file=fullfile(work,'SCM_hover_fixture.m'); fid=fopen(file,'w'); fwrite(fid,char(source)); fclose(fid);
pathGuard=onCleanup(@()rmpath(work)); %#ok<NASGU>
rng(17);
for nz=[1 4 54]
    nt=1500;
    P=single(5*randn(24,28,nz,nt));
    P(5,5,:,:)=NaN;
    if nz==1, P=reshape(P,24,28,nt); end
    b=struct('start',0,'end',10,'sigStart',30,'sigEnd',50,'mode','sec');
    f=SCM_hover_fixture(P,ones(24,28,nz),.5,struct(),b,nt,'Hover regression');
    % Physical pointer events must not interfere with deterministic queued
    % test coordinates when other MATLAB sessions share the desktop.
    set(f,'WindowButtonMotionFcn',[],'WindowScrollWheelFcn',[]);
    figGuard=onCleanup(@()delete(f));
    h=getappdata(f,'HoverTest'); drawnow;
    changes=0; listener=addlistener(h.trace,'YData','PostSet',@countUpdate);
    startTime=tic;
    for k=1:250, h.queue(3+mod(k,20),3+mod(k,16)); end
    h.queue(12,10);
    waitTrace();
    assert(changes>=1 && changes<=5,'Mouse burst queued redundant trace redraws.');
    assert(isequal(get(h.rect,'Position'),[10 8 5 5]));
    assert(strcmp(h.timer.Running,'off'),'Idle hover timer did not stop.');
    fprintf('PASS %d slices: 251 requests -> %d trace update; settled %.3f s.\n',nz,changes,toc(startTime));
    if nz>1
        set(h.slice,'Value',1); h.sliceChanged([],[]); % Last native slice.
    end
    h.queue(12,10); waitTrace();
    z=nz;
    if nz==1, X=P(8:12,10:14,:); else, X=reshape(P(8:12,10:14,z,:),5,5,nt); end
    B=mean(X(:,:,1:21),3,'omitnan');
    expected=100*(X-B)./(100+B);
    expected=mean(reshape(expected,25,nt),1,'omitnan');
    idx=1:ceil(nt/1200):nt;
    difference=max(abs(get(h.trace,'YData')-double(expected(idx))));
    assert(difference<1e-5,sprintf('Trace error %.6g, slice %d, rectangle %s',difference,nz,mat2str(get(h.rect,'Position'))));
    % A pinned ROI and its full-resolution time course are unchanged.
    h.add(12,10); pinned=findall(f,'Tag','SCM_SavedROI');
    assert(numel(pinned)==1 && numel(get(pinned,'YData'))==nt);
    assert(max(abs(get(pinned,'YData')-double(expected)))<1e-5);
    before=get(h.rect,'Position'); h.queue(20,20); waitTrace();
    assert(isequal(before,get(h.rect,'Position')),'Frozen ROI moved.');
    h.unfreeze([],[]); h.queue(12,10); waitTrace();
    assert(strcmp(get(h.trace,'Visible'),'on'),'Same-coordinate hover did not resume.');
    set(h.base,'String','10-20'); h.window([],[]); h.queue(12,10); waitTrace();
    B=mean(X(:,:,21:41),3,'omitnan'); expected=mean(reshape(100*(X-B)./(100+B),25,nt),1,'omitnan');
    assert(max(abs(get(h.trace,'YData')-double(expected(idx))))<1e-5);
    % Cached pinned bounds must give exactly the original automatic limits.
    h.queue(20,18); waitTrace();
    pinned=findall(f,'Tag','SCM_SavedROI');
    y=[get(pinned,'YData') get(h.trace,'YData')]; y=y(isfinite(y));
    pad=max(.15*(max(y)-min(y)),.5);
    ax=ancestor(h.trace,'axes');
    assert(max(abs(get(ax,'YLim')-[min(y)-pad max(y)+pad]))<1e-8);
    delete(listener); timerHandle=h.timer; clear figGuard;
    assert(~isvalid(timerHandle),'Closing SCM leaked a timer.');
end
for nz=[1 4 54]
    P=single(5*randn(48,50,nz,90)); P(:,8:10,:,3:7:end)=NaN;
    if nz==1, P=reshape(P,48,50,90); end
    b=struct('start',0,'end',10,'sigStart',30,'sigEnd',40,'mode','sec');
    f=SCM_hover_fixture(P,ones(48,50,nz),.5,struct(),b,90,'Large ROI regression');
    figGuard=onCleanup(@()delete(f)); set(f,'WindowButtonMotionFcn',[],'WindowScrollWheelFcn',[]);
    h=getappdata(f,'HoverTest');
    if nz>1, set(h.slice,'Value',1); h.sliceChanged([],[]); end
    positions=[25 24;26 24;26 25;8 9;9 9;25 24];
    for width=[35 41 35]
        set(h.size,'Value',width); h.resize();
        for k=1:size(positions,1)
            h.queue(positions(k,1),positions(k,2)); waitTrace();
            p=get(h.rect,'Position'); expected=h.direct(nz,p(1),p(1)+p(3)-1,p(2),p(2)+p(4)-1,1:90);
            actual=get(h.trace,'YData'); valid=isfinite(expected);
            assert(isequal(isnan(actual),isnan(expected)) && max(abs(actual(valid)-expected(valid)))<2e-5);
        end
    end
    clear figGuard;
    fprintf('PASS incremental large ROI: %d slices, NaNs, diagonal motion, jumps, clipped edges and size changes.\n',nz);
end
fprintf('PASS SCM hover coalescing, final location, slice/baseline changes, pinned full-resolution ROI and cleanup.\n');
    function countUpdate(~,~), changes=changes+1; end
    function waitTrace()
        deadline=tic;
        while toc(deadline)<2
            pause(.05);
            if strcmp(h.timer.Running,'off'), return; end
        end
        error('test:HoverTimeout','Hover did not settle.');
    end
end
