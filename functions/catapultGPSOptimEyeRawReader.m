%Copyright (C) 2014  Timo Rantalainen tjrantal at gmail dot com
%
%   This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.

%Catapult raw file reader. Reverse engineered, so will not work for all catapult files
%Magnetometer scaling might be incorrect
%Cannot handle compressed files under any circumstance
%The sign of data differs between data read from raw files with this function and corresponding data exported with the Catapult Sprint software.
function data = catapultGPSOptimEyeRawReader(fileIn,samplingFreq)

	%Helper function to extract values from header strings
	function value = getHeaderValue(header,toLookFor,separator)
		counter = 1;
		while counter < length(header) && isempty(strfind(lower(header(counter).string),lower(toLookFor)))
			counter = counter+1;
		end
		if ~isempty(strfind(lower(header(counter).string),lower(toLookFor)))
			tempString = lower(header(counter).string);
			valueStrings = strsplit(tempString,separator);
			value = valueStrings{2};
		else
			value = nan;
		end
	end

	%FILE READER BEGINS
	%String constants to extract data from the header
	%Gyroscope scaling coefficients. For some reasong DGyrZ0 - 2 do not add up.
	%gyroToLookFor = {'dgyrz0','dgyrg0','dgyrz1','dgyrg1','dgyrz2','dgyrg2'};
	gyroToLookFor = {'gyrozero1','gyrogain1','gyrozero2','gyrogain2','gyrozero0','gyrogain0'};
	%Accelerometer scaling coefficients.
	%accToLookFor = {'DAcc+0','DAcc-0','DAcc+1','DAcc-1','DAcc+2','DAcc-2'};
    accToLookFor = {'PlusG2','MinusG2','PlusG1','MinusG1','PlusG0','MinusG0'};
	%Magnetometer scaling coefficients
	%magToLookFor = {'Mag+0','DMag-0','DMag+1','DMag-1','DMag+2','DMag-2'};
	magToLookFor = {'PlusMag2','MinusMag2','PlusMag1','MinusMag1','PlusMag0','MinusMag0'};
	
	fh = fopen(fileIn,'rb');
	data = struct();
	%Read the header data
	data.headerData = char(fread(fh, 1024,'uint8'));
	fieldBeginnings = find(data.headerData == '$')+1;
	fieldEnds = [fieldBeginnings(2:end)-3; find(data.headerData == ',',1,'last')-1];%find(data.headerData == ',')-1;
	data.header = struct();
	%Save the header data in strings
	for i = 1:length(fieldBeginnings)
		data.header(i).string = data.headerData(fieldBeginnings(i):fieldEnds(i))';
	end
	data.startTime =  double(str2double(getHeaderValue(data.header,'Time',':')));
	data.ID = getHeaderValue(data.header,'DeviceID',':');
	%Extract calibrations from the header
	for i = 1:length(gyroToLookFor)
		data.gyroCalib(i) = str2double(getHeaderValue(data.header,gyroToLookFor{i},'='));
	end


	for i = 1:length(accToLookFor)
		data.accCalib(i) = str2double(getHeaderValue(data.header,accToLookFor{i},'='));
	end

	for i = 1:length(magToLookFor)
		data.magCalib(i) = str2double(getHeaderValue(data.header,magToLookFor{i},'='));
	end

	%Find out how many datasets exist in the file
	fseek(fh,-1024,'eof');
	fileLength = ftell(fh);
    fseek(fh, 1024, 'bof');
    
    packetIdentifiers = [ ...
                            [uint8(hex2dec('70')),uint8(hex2dec('8C'))]; ...    %GPS 2+139
                            [uint8(hex2dec('7D')),uint8(hex2dec('13'))]; ...     %IMU packet 2+19
                            [uint8(hex2dec('20')),uint8(hex2dec('16'))]; ...    %GPS date 2+21
                            [uint8(hex2dec('20')),uint8(hex2dec('18'))]; ...     %GPS time 2+21
                        ];
    packetLengths = [2+139,2+19,2+21,2+21];
	
	%Read data to memory
    memData = uint8(fread(fh,fileLength-1024,'uint8'));
    fclose(fh);
	%Constants for the types of data in file
% 	recordType = {'uint8' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16' 'uint16'};
    recordType = {'uint8' 'int16' 'int16' 'int16' 'int16' 'int16' 'int16' 'int16' 'int16' 'int16'};
    recordIndices = {2};
    t = 1;
    for i = 3:2:19
        t = t+1;
        recordIndices{t} = [i:i+1];
    end

	data.channels = cell(1,numel(recordType));
    data.GPS = {};
    data.GPSdate = {};
    data.GPStime = {};
    data.speed = {};
    
%     %Use the java class to read the data
%     cRead = javaObject('deakin.timo.catapultRead.CatapultRead',double(memData));%
%     counters = cRead.getCounters();
%     figure,plot(counters);
%     jData = cRead.getData()';
%     figure,plot(jData(:,1:3))
%     keyboard;
%     
    %The file has a dicom-file type structure with data fields, and
    %corresponding binary data
    if 1
        i = 1;

        ignore = 0;
        while i<length(memData) %&& i< 1000000
            switch typecast(memData(i:i+1),'uint16') 
                case typecast(packetIdentifiers(1,:),'uint16')  %GPS 2+139
                    data.GPS{end+1} = memData(i+2:i+2-1+packetLengths(1)-2);
                    data.speed = [data.speed double(typecast(data.GPS{end}(81:(81+3)),'int32'))/1000 ];
%                     if data.speed{end} > 0
%                        keyboard; 
%                     end
                    i = i+packetLengths(1);
                case typecast(packetIdentifiers(2,:),'uint16')  %IMU packet 2+19
                    %Decode IMU packet
                    if ignore < 50          %Ignore first 50 data points, the device needs to settle in first
                        ignore = ignore+1;
                    else
                        data.channels{1} = [data.channels{1} memData(i+recordIndices{1})];
                        for d=2:length(recordIndices)
                            data.channels{d} = [data.channels{d} typecast(memData(i+recordIndices{d}),recordType{d})];
                        end
                    end
                    i = i+packetLengths(2);
                case typecast(packetIdentifiers(3,:),'uint16')  %GPS date 2+21
                    data.GPSdate{end+1} = memData(i+2:i+2+packetLengths(3));
                    i = i+packetLengths(3);
                case typecast(packetIdentifiers(4,:),'uint16')  %GPS time 2+21
                    data.GPStime{end+1} = memData(i+2:i+2+packetLengths(4));
                    i = i+packetLengths(4);
                otherwise   %Unknown package
                    i = i+1;
            end
%             disp(sprintf('i = %06d\r',i));
        end
        
%         figure
%         subplot(3,1,1)
%         hold on;
%         plot(data.channels{2},'r');
%         plot(data.channels{3},'g');
%         plot(data.channels{4},'b');
%         subplot(3,1,2)
%         hold on;
%         plot(data.channels{5},'r');
%         plot(data.channels{6},'g');
%         plot(data.channels{7},'b');
%         subplot(3,1,3)
%         hold on;
%         plot(data.channels{8},'r');
%         plot(data.channels{9},'g');
%         plot(data.channels{10},'b');
%         keyboard;
    end

    %Scale the data
    %scale GRF
    for i = 2:10
        if i >= 2 && i<=4	
                accCVector = [data.accCalib((i-1)*2-1); data.accCalib((i-1)*2)];
                A = [repmat(1,2,1) accCVector];
                B = [1; -1];
                coefficient = A\B;
                data.channels{i} = double(data.channels{i})*coefficient(2)+coefficient(1);
            end
            %scale gyro
            if i >= 5 && i<=7	
                gyroCVector = [data.gyroCalib((i-4)*2-1); data.gyroCalib((i-4)*2)];
                data.channels{i} = (double(data.channels{i})-gyroCVector(1))*gyroCVector(2);	%16 bit, +-16g
            end
            %scale magnetometer
            if i >= 8 && i<=10	
                magCVector = [data.magCalib((i-7)*2-1); data.magCalib((i-7)*2)];
                A = [repmat(1,2,1) magCVector];
                B = [1; -1];
                coefficient = A\B;
                data.channels{i} = double(data.channels{i})*coefficient(2)+coefficient(1);
            end
    end

	data.time = ([0:(length(data.channels{1})-1)]'*(1/double(samplingFreq)));
	data.samplingFreq =	double(samplingFreq);
end