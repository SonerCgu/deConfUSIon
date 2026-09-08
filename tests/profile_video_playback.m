function profile_video_playback(compareBefore)
if nargin<1, compareBefore=false; end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
work=tempname; mkdir(work); addpath(work); pathGuard=onCleanup(@()rmpath(work)); %#ok<NASGU>
if compareBefore, source=fileread(fullfile(root,'validation','video_before_source.m'));
else, source=fileread(fullfile(root,'play_fusi_video_final.m')); end
source=strrep(source,'function fig = play_fusi_video_final(', 'function fig = video_profile_fixture(');
marker='    function timerTick(~,~)';
hooks="setappdata(fig,'VideoTest',struct('tick',@timerTick,'render',@render,'play',@playPause,'button',playBtn,'timer',playTimer,'image',img,'brightness',slBri));";
source=strrep(source,marker,char(hooks+newline+marker));
fid=fopen(fullfile(work,'video_profile_fixture.m'),'w'); fwrite(fid,source); fclose(fid);
for nz=[1 4 54]
    rng(31); I=single(100+randn(80,64,nz,40)); P=I-100;
    if nz==1, I=reshape(I,80,64,40); P=reshape(P,80,64,40); end
    par=struct('interpol',1,'previewCaxis',[-5 5]);
    b=struct('start',0,'end',5,'mode','sec');
    f=video_profile_fixture(I,I,P,rand(80,64,nz),par,20,240,1,39,b,[],true,40,false,struct(),'Playback performance',1);
    guard=onCleanup(@()close(f)); h=getappdata(f,'VideoTest');
    set(f,'WindowButtonMotionFcn',[]); drawnow;
    set(h.button,'Value',1); h.play(h.button,[]); stop(h.timer);
    elapsed=zeros(1,25);
    for k=1:25
        t=tic; h.tick([],[]); drawnow limitrate nocallbacks; elapsed(k)=toc(t);
    end
    fprintf('Video before=%d slices=%d: median %.4f s, max %.4f s; RGB size %s\n',compareBefore,nz,median(elapsed(3:end)),max(elapsed),mat2str(size(get(h.image,'CData'))));
    if ~compareBefore
        assert(isequal(size(get(h.image,'CData')),[80 64 3]));
        cached=get(h.image,'CData'); h.render(); h.render(true);
        assert(max(abs(cached(:)-reshape(get(h.image,'CData'),[],1)))<1e-12,'Cached underlay changes frame values.');
        % Changing a manual underlay control must invalidate playback cache.
        set(h.brightness,'Value',min(get(h.brightness,'Max'),get(h.brightness,'Value')+.15));
        cb=get(h.brightness,'Callback'); cb(h.brightness,[]); h.render(true);
        assert(any(abs(cached(:)-reshape(get(h.image,'CData'),[],1))>1e-8));
        % Run the actual playback timer while the save queue is pending.
        output=fullfile(work,sprintf('video_save_%d.mat',nz));
        DataIO('enqueue',output,struct('newData',struct('I',I,'TR',1)));
        h.play(h.button,[]); pause(.35); DataIO('poll');
        assert(strcmp(DataIO('status',output),'queued'),'Save queue interrupted playback.');
        assert(h.timer.TasksExecuted>=2,'Playback timer did not advance.');
    end
    set(h.button,'Value',0); h.play(h.button,[]);
    timerHandle=h.timer; clear guard; assert(~isvalid(timerHandle));
    if ~compareBefore, DataIO('wait'); saved=load(output); assert(isequal(saved.newData.I,I)); end
end
fprintf('PASS playback profiling, underlay cache and timer cleanup.\n');
end
