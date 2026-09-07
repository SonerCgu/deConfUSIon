function test_real_raw_processing()
% Read-only validation on the reported single-slice acquisition.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
source='Z:\fUS\Project_PACAP_AVATAR_SC\RawData\AprilStayLeuven\PACAP\WT250407_S1\Mouse250407_S1_Ringer_FUS_151142.mat';
t=tic; S=load(source,'I'); fprintf('REAL RAW load: %.3f s, size %s\n',toc(t),mat2str(size(S.I)));
data=struct('I',S.I,'TR',.2); clear S;
for method={'pca','ica'}
    captured=false; began=tic;
    watcher=timer('ExecutionMode','fixedSpacing','Period',.5,'TimerFcn',@captureComponents);
    guard=onCleanup(@()delete(watcher)); start(watcher);
    if strcmp(method{1},'pca'), [out,stats]=pca_denoise(data,tempdir,'real 2D raw Ringer');
    else, [out,stats]=ica_denoise(data,tempdir,'real 2D raw Ringer'); end
    assert(captured,'Component window never reached its interactive state.');
    assert(~stats.applied && isequal(out.I,data.I)); clear out guard;
end
t=tic; [filtered,~]=filtering(data.I,data.TR,tempdir,struct('type','low','FcHigh',.2,'saveQC',false));
assert(isequal(size(filtered),size(data.I)) && all(isfinite(filtered(:))));
fprintf('REAL RAW full filtering: %.3f s\n',toc(t)); clear filtered;
t=tic; out=imregdemons_preprocess(data.I(:,:,1:40),data.TR,struct('nsub',10,'saveQC',false,'showQC',false,'iterations',[10 5 2]));
assert(isequal(size(out.I),[156 256 4]) && all(isfinite(out.I(:))));
fprintf('REAL RAW imregdemons first 40 frames: %.3f s\n',toc(t));
fprintf('PASS real raw processing.\n');
    function captureComponents(~,~)
        figures=findall(0,'Type','figure');
        for h=reshape(figures,1,[])
            if startsWith(get(h,'Name'),upper(method{1})+" -") && strcmp(get(h,'WaitStatus'),'waiting')
                assert(numel(findall(h,'Type','axes'))>=26);
                drawnow; shot=getframe(h); imwrite(shot.cdata,fullfile(root,'validation',['ringer_' method{1} '_window.png']));
                fprintf('REAL RAW %s interactive window: %.3f s\n',upper(method{1}),toc(began));
                captured=true; stop(watcher); cb=get(h,'CloseRequestFcn'); cb(h,[]);
            end
        end
    end
end
