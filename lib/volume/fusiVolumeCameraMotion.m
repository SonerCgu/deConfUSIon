function [position,up]=fusiVolumeCameraMotion(position,target,up,seconds,opt)
% Camera motion only; no functional interpolation or change of PSC values.
offset=position-target;up=up/norm(up);right=cross(offset,up);right=right/norm(right);
switch opt.path
 case 'Gentle yaw',yaw=opt.amplitude*sin(opt.speed*seconds/opt.amplitude);pitch=0;
 case 'Gentle tilt',yaw=0;pitch=opt.amplitude*sin(opt.speed*seconds/opt.amplitude);
 case 'Oblique orbit',yaw=opt.speed*seconds;pitch=opt.amplitude*sin(deg2rad(yaw));
 case 'Fixed camera',yaw=0;pitch=0;
 otherwise,yaw=opt.speed*seconds;pitch=0;
end
offset=rotate(offset,up,deg2rad(yaw));right=rotate(right,up,deg2rad(yaw));
offset=rotate(offset,right,deg2rad(pitch));up=rotate(up,right,deg2rad(pitch));
position=target+offset;
end
function v=rotate(v,axis,angle)
v=v*cos(angle)+cross(axis,v)*sin(angle)+axis*dot(axis,v)*(1-cos(angle));
end
