% 文件名: main_rotor_full.m
clc; clear all; close all;

%% 1. 真实物理尺寸与拓扑参数加载
Dse = 400; Ds = 260; Dre = 258; Dri = 85; 
poles = 4; p = poles/2;  
gap = (Ds - Dre) / 2;

bridge = 1; 
wbr = bridge * [0 0.8 1]; 
rib = 1; 
Rrib = Dre/2 - rib; 
Rbrrd = Rrib * [0.96, 0.88, 0.91]; 
Rbrrs = Rrib * [0.99, 0.95, 0.95]; 

theta_b1 = 15.7 * pi / 180; 
theta_b2 = 28.9 * pi / 180; 
theta_b3 = 40.4 * pi / 180;
delta_theta1 = 0.5 * pi / 180; 
delta_theta2 = 0.5 * pi / 180; 
delta_theta3 = 0.5 * pi / 180;

kair = 0.36; 
ltot = (Dre - Dri)/2; 
lair = ltot * kair;   
lfe  = ltot - lair;   

%% 2. 磁动势 (MMF) 分配与绝对坐标解算
f1 = (1-cos(p*theta_b1)) / (p*theta_b1);
f2 = (cos(p*theta_b1)-cos(p*theta_b2)) / (p*(theta_b2-theta_b1));
f3 = (cos(p*theta_b2)-cos(p*theta_b3)) / (p*(theta_b3-theta_b2));
f4 = (cos(p*theta_b3)) / ((pi/2)-p*theta_b3);
f_sum = f1 + f2 + f3 + (f4/2);

wf4 = (1*f4/2/f_sum)*lfe;
wf3 = (1*f3/f_sum)*lfe;
wf2 = (1*f2/f_sum)*lfe;

fq1 = (sin(p*theta_b1)) / (p*theta_b1);
fq2 = (sin(p*theta_b2)-sin(p*theta_b1)) / (p*(theta_b2-theta_b1));    
fq3 = (sin(p*theta_b3)-sin(p*theta_b2)) / (p*(theta_b3-theta_b2));

Dfq1 = fq1 - fq2; 
Dfq2 = fq2 - fq3; 
Dfq3 = fq3;

c12 = (Dfq1/Dfq2)*sqrt(theta_b1/theta_b2);
c23 = (Dfq2/Dfq3)*sqrt(theta_b2/theta_b3);

tb1 = lair / (1 + 1/c12 + (1/c12)/c23); 
tb2 = lair / (c12 + 1 + (1/c23)); 
tb3 = lair / (c12*c23 + c23 + 1); 

ri3 = (Dri/2) + wf4; ro3 = ri3 + tb3;   
ri2 = ro3 + wf3;     ro2 = ri2 + tb2;
ri1 = ro2 + wf2;     ro1 = ri1 + tb1;

radii_all = [ri1 ro1; ri2 ro2; ri3 ro3];
theta_b_all = [theta_b1, theta_b2, theta_b3];
delta_theta_all = [delta_theta1, delta_theta2, delta_theta3];
Rbrr_all = [Rbrrd(1) Rbrrs(1); Rbrrd(2) Rbrrs(2); Rbrrd(3) Rbrrs(3)];

%% 3. 初始化 VBS 脚本引擎并强制存盘
folderPath = 'C:\Benny\local_file';
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
vbs_path = fullfile(folderPath, 'Full_Rotor_Test.vbs');
fid = fopen(vbs_path, 'w');

fprintf(fid, 'Set app = CreateObject("designer.Application.230")\n');
fprintf(fid, 'app.Show()\n');
fprintf(fid, 'Call app.NewProject("Rotor360")\n');
fprintf(fid, 'Call app.SaveAs("C:\\Benny\\local_file\\Rotor360.jproj")\n');
fprintf(fid, 'Set geomApp = app.CreateGeometryEditor()\n');
fprintf(fid, 'Set refPlane = geomApp.GetDocument().GetAssembly().GetItem(0)\n');
fprintf(fid, 'Set refRef = geomApp.GetDocument().CreateReferenceFromItem(refPlane)\n');
fprintf(fid, 'Call geomApp.GetDocument().GetAssembly().CreateSketch(refRef)\n');

sketch_index = 3;
fprintf(fid, 'Set sketch = geomApp.GetDocument().GetAssembly().GetItem(%d)\n', sketch_index);
fprintf(fid, 'Call sketch.OpenSketch()\n');

%% 4. 执行 360 度空间阵列曲线绘制 (核心循环)
fprintf('正在解算 360 度全转子空间阵列并写入机器码...\n');

for layer = 1:3
    for pole = 1:poles
        angle_offset = (pole - 1) * (2*pi/poles);
        for mirror_sign = [1, -1]
            draw_barrier_360(fid, sketch_index, Dri, Rrib, radii_all(layer,:), poles, ...
                theta_b_all(layer), wbr(layer), Rbrr_all(layer,:), delta_theta_all(layer), angle_offset, mirror_sign);
        end
    end
end

% 绘制转子内外边界圆
fprintf(fid, 'Call sketch.CreateCircle(0, 0, %.6f)\n', Dre/2);
fprintf(fid, 'Call sketch.CreateCircle(0, 0, %.6f)\n', Dri/2);

%% 5. 统一闭封并推送至主程序
fprintf(fid, 'Call sketch.CreateRegions()\n');
fprintf(fid, 'Call sketch.CloseSketch()\n');
fprintf(fid, 'Call app.ImportDataFromGeometryEditor()\n');
fclose(fid);

%% 6. 呼叫脚本控制台
fprintf('正在自动唤醒 JMAG 进行完整转子拓扑构建...\n');
status = system(['cscript -nologo "', vbs_path, '"']);

if status == 0
    fprintf('\n[指令下发成功] 请前往 JMAG 查看 360 度全尺寸转子线框！\n');
else
    fprintf('\n[异常] 脚本执行失败。\n');
end