classdef vfusiSensoryRun < handle
    % One software start per acquired stream; RF/image arrays never modified.
    properties (SetAccess=private)
        config; runId=''; file=-1; socket=[]; started=false; clock=[]; folder=''; acknowledged=false;
    end
    methods
        function obj=vfusiSensoryRun(c)
            obj.config=vfusiSensoryConfig(c);
            if strcmp(obj.config.mode,'psychopy')
                obj.socket=java.net.DatagramSocket();obj.socket.setSoTimeout(2000);
                try,obj.ping();catch ME,obj.socket.close();obj.socket=[];rethrow(ME);end
            end
        end
        function ping(obj)
            nonce=char(java.util.UUID.randomUUID());obj.send(struct('event','PING','nonce',nonce));
            packet=java.net.DatagramPacket(zeros(1,8192,'int8'),8192);
            try
                obj.socket.receive(packet);bytes=typecast(packet.getData(),'uint8');bytes=bytes(:)';reply=jsondecode(char(bytes(1:packet.getLength())));
            catch ME
                error('vfUSI:SensoryNotReady','PsychoPy worker did not answer correctly. ARM it before starting acquisition. Details: %s',ME.message);
            end
            if ~strcmp(reply.event,'READY')||~strcmp(reply.nonce,nonce)
                error('vfUSI:SensoryNotReady','Stimulus worker is busy or replied with a mismatched session.');
            end
            if ~isfield(reply,'protocol_sha256')||~strcmp(reply.protocol_sha256,obj.protocolHash())
                error('vfUSI:SensoryNotReady','The worker uses different protocol settings. Close the old worker (Escape), then ARM the saved configuration.');
            end
        end
        function begin(obj,label)
            obj.finish();
            if strcmp(obj.config.mode,'psychopy'),obj.ping();end
            obj.runId=[datestr(now,'yyyy-mm-dd_HH-MM-SS-FFF') '_' char(java.util.UUID.randomUUID())];
            obj.folder=fullfile(obj.config.output_dir,['scan_' obj.runId]);mkdir(obj.folder);
            copyfile(obj.config.protocol_file,fullfile(obj.folder,'protocol.json'));
            obj.file=fopen(fullfile(obj.folder,'scan_events.jsonl'),'w');
            if obj.file<0,error('vfUSI:SensoryLog','Cannot open sensory event log.');end
            obj.clock=tic;obj.started=false;obj.acknowledged=false;obj.log('ARMED',0,label);
        end
        function frame(obj,index)
            if obj.file<0,return;end
            if ~obj.started
                obj.started=true;obj.log('START',index,'First scanner callback; software event, not acquisition TTL');
                if strcmp(obj.config.mode,'psychopy')
                    try,obj.send(struct('event','START','run_id',obj.runId));
                    catch ME,obj.log('SYNC_ERROR',index,ME.message);end
                    % Never wait for screen refresh/serial reply in processRF.
                end
            end
            obj.log('FRAME',index,'Scanner callback index');
        end
        function info=metadata(obj)
            info=struct('mode',obj.config.mode,'run_id',obj.runId,'log_folder',obj.folder, ...
                'protocol_file',fullfile(obj.folder,'protocol.json'),'worker_start_acknowledged',obj.acknowledged, ...
                'timing_reference','First acquired-frame callback; not a measured hardware TTL edge');
        end
        function finish(obj)
            if obj.file<0,return;end
            if obj.started && strcmp(obj.config.mode,'psychopy')
                % Receive the queued acknowledgement only after acquisition.
                packet=java.net.DatagramPacket(zeros(1,8192,'int8'),8192);
                try
                    obj.socket.receive(packet);bytes=typecast(packet.getData(),'uint8');bytes=bytes(:)';reply=jsondecode(char(bytes(1:packet.getLength())));
                    obj.acknowledged=strcmp(reply.event,'STARTED')&&strcmp(reply.run_id,obj.runId);
                catch,obj.acknowledged=false;end
                if obj.acknowledged,obj.log('WORKER_ACK',0,'Acknowledgement read after acquisition');
                else,obj.log('SYNC_ERROR',0,'No matching START acknowledgement; scanner data must still be saved');end
                try,obj.send(struct('event','STOP','run_id',obj.runId));
                catch ME,obj.log('SYNC_ERROR',0,ME.message);end
            end
            obj.log('STOP',0,'Scan ended, failed or cancelled');fclose(obj.file);obj.file=-1;obj.started=false;
        end
        function delete(obj)
            obj.finish();if ~isempty(obj.socket),obj.socket.close();obj.socket=[];end
        end
    end
    methods (Access=private)
        function hash=protocolHash(obj)
            fid=fopen(obj.config.protocol_file,'rb');guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
            bytes=fread(fid,Inf,'*uint8');digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(typecast(bytes,'int8'));
            raw=typecast(digest.digest(),'uint8');hash=lower(reshape(dec2hex(raw,2)',1,[]));
        end
        function send(obj,event)
            bytes=unicode2native(jsonencode(event),'UTF-8');
            packet=java.net.DatagramPacket(typecast(uint8(bytes),'int8'),numel(bytes),java.net.InetAddress.getByName(obj.config.udp_host),obj.config.udp_port);
            obj.socket.send(packet);
        end
        function log(obj,event,index,note)
            if obj.file<0,return;end
            row=struct('event',event,'frame',index,'elapsed_s',toc(obj.clock),'wall_clock',datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'), 'run_id',obj.runId,'note',note);
            fprintf(obj.file,'%s\n',jsonencode(row));
        end
    end
end
