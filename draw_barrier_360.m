function draw_barrier_360(fid, sketch_index, Dri, Rrib, radii, poles, theta_b, wbr, Rbrr, delta_theta, angle_offset, mirror_sign)
% -------------------------------------------------------------------------
% 360度全尺寸转子阵列绘图算子 (包含防爆钳制与1-based索引修复)
% -------------------------------------------------------------------------
  sketch_cmd = sprintf('Call geomApp.GetDocument().GetAssembly().GetItem(%d)', sketch_index);
  flag = 0; indx = 0; p = poles/2;
  thmax = pi/(2*p); thmin = thmax / 100; Nangl = 30; dth = (thmax - thmin) / Nangl; 
  
  if wbr ~= 0
    wbr = wbr/2; 
    x_d = radii(1)*cos(thmax); y_d = radii(1)*sin(thmax);
    x_u = radii(2)*cos(thmax); y_u = radii(2)*sin(thmax);
    x_br = [x_d x_u]; y_br = [y_d y_u];
  end
  
  x = zeros(2, Nangl+1); y = zeros(2, Nangl+1); c = zeros(1, 2); 
  x_pen = zeros(1, 2); y_pen = zeros(1, 2); x_fin = zeros(1, 2); y_fin = zeros(1, 2);     
  dydx  = zeros(1, 2); x0 = zeros(1, 2); y0 = zeros(1, 2); 
  
  for cc = 1 : 2
      c(cc) = (sin(p*thmax)*( ((2*radii(cc)/Dri)^(2*p)) -1)) / ((2*radii(cc)/Dri)^p) ;
  end
  
  for cc = 1: 2 
	flag = 1; indx = 0;          
    for tt = 1 : (Nangl + 1)
		theta = thmax - dth*(tt-1); 
        num_r = c(cc) + sqrt( (c(cc)^2) + ((2*sin(p*theta))^2) );
    	den_r = 2*sin(p*theta);
        radius = (Dri/2) * (((num_r/den_r)^(1/p))); 
        
        if (cc == 2 && radius < radii(1)), radius = radii(1); end
        
        if (radius <= Rbrr(cc)) 
			flag = 1; indx = indx + 1;
            x(cc,tt) = radius * cos(theta); 
            y(cc,tt) = radius * sin(theta);
        else		
            if flag == 1
                flag = -1; indx = indx + 1;
                if tt == 1
                    x_pen(cc) = Rbrr(cc) * cos(theta); y_pen(cc) = Rbrr(cc) * sin(theta);
                else
                    x_pen(cc) = x(cc,tt-1); y_pen(cc) = y(cc,tt-1);
                end
                
                num_th = c(cc)* ( (2*Rbrr(cc)/Dri)^p );
				den_th = ( (2*Rbrr(cc)/Dri)^(2*p) ) - 1;
                asin_val = num_th / den_th;
                if asin_val > 1, asin_val = 1; elseif asin_val < -1, asin_val = -1; end
                theta_fin = (1/p) * asin(asin_val); 
                
                x(cc,tt)  = Rbrr(cc) * cos(theta_fin); 
                y(cc,tt)  = Rbrr(cc) * sin(theta_fin);
                x_fin(cc) = x(cc,tt); 
                y_fin(cc) = y(cc,tt);
                
                if abs(x_fin(cc) - x_pen(cc)) < 1e-6
                    dydx(cc) = 1e6; 
                else
                    dydx(cc) = ( y_fin(cc) - y_pen(cc) ) / ( x_fin(cc) - x_pen(cc) );
                end
            else
                flag = -1; x(cc,tt) = x(cc,tt-1); y(cc,tt) = y(cc,tt-1);
            end			
        end
    end
  end			

  if wbr == 0  
	for cc = 1: 2 
		for ii = 1:Nangl
            write_line(fid, sketch_cmd, x(cc,ii), y(cc,ii), x(cc,ii+1), y(cc,ii+1), angle_offset, mirror_sign);
		end
    end
    write_line(fid, sketch_cmd, x(1,1), y(1,1), x(2,1), y(2,1), angle_offset, mirror_sign);
  else  
    x_min = zeros(1, 2); y_min = zeros(1, 2); 
    for cc = 1:2
		ii_begin = 1; x_tempo = x_br(cc); y_tempo = y_br(cc); 
        lambda = sqrt( (wbr^2) / (1+ (tan(thmax))^2) );
        xP = x_br(cc) + lambda; yP = y_br(cc) + lambda*tan(thmax);
        [x_b, y_b] = rotation(x_br(cc), y_br(cc), xP, yP, -pi/2);
        distance = sqrt(((x_br(cc)-x_tempo)^2)+((y_br(cc)-y_tempo)^2));				
        while (distance <= wbr && ii_begin < Nangl)
			ii_begin = ii_begin+1;
            x_tempo = x(cc,ii_begin); y_tempo = y(cc,ii_begin);
			distance = sqrt(((x_br(cc)-x_tempo)^2)+((y_br(cc)-y_tempo)^2));
        end
        x_min(cc) = x_b; y_min(cc) = y_b; ind = ii_begin;
        
        write_line(fid, sketch_cmd, x_b, y_b, x(cc, ind), y(cc,ind), angle_offset, mirror_sign);
        for ii = ind:Nangl
			write_line(fid, sketch_cmd, x(cc,ii), y(cc,ii), x(cc,ii+1), y(cc,ii+1), angle_offset, mirror_sign);
        end
    end 
    write_line(fid, sketch_cmd, x_min(1), y_min(1), x_min(2), y_min(2), angle_offset, mirror_sign);
  end

  x00 = Rrib*cos((pi/(2*p))-theta_b); y00 = Rrib*sin((pi/(2*p))-theta_b);
  for cc = 1: 2
    npt_s = 10; 
    th0 = ((pi/(2*p)) - theta_b) + ((-1)^(cc))*delta_theta; 
    x0(cc) = Rrib*cos(th0); y0(cc) = Rrib*sin(th0);
    den = (x_fin(cc)-x0(cc))^2;
    if den < 1e-8, den = 1e-8; end
    a = (dydx(cc)*(x_fin(cc)-x0(cc))-(y_fin(cc)-y0(cc))) / den;
    b = dydx(cc) - 2*a*x_fin(cc); 
    c = y_fin(cc) - a*x_fin(cc)^2 - b*x_fin(cc);
    x_aux = x_fin(cc); y_aux = y_fin(cc);
    for i = 1: npt_s 
        xx = x_fin(cc)+(x0(cc)-x_fin(cc))*(i/npt_s); yy = a*(xx^2) + b*xx + c;
        write_line(fid, sketch_cmd, xx, yy, x_aux, y_aux, angle_offset, mirror_sign);
        x_aux = xx; y_aux = yy;
    end
    write_line(fid, sketch_cmd, x0(cc), y0(cc), x00, y00, angle_offset, mirror_sign);
  end 
end

function write_line(fid, sketch_cmd, x1, y1, x2, y2, angle_offset, mirror_sign)
    y1 = y1 * mirror_sign; y2 = y2 * mirror_sign;
    xt1 = x1 * cos(angle_offset) - y1 * sin(angle_offset);
    yt1 = x1 * sin(angle_offset) + y1 * cos(angle_offset);
    xt2 = x2 * cos(angle_offset) - y2 * sin(angle_offset);
    yt2 = x2 * sin(angle_offset) + y2 * cos(angle_offset);
    fprintf(fid, '%s.CreateLine(%.6f, %.6f, %.6f, %.6f)\n', sketch_cmd, xt1, yt1, xt2, yt2);
end

function [xr, yr] = rotation(xc, yc, x, y, theta)
    xr = xc + (x - xc)*cos(theta) - (y - yc)*sin(theta);
    yr = yc + (x - xc)*sin(theta) + (y - yc)*cos(theta);
end