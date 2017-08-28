package deakin.timo.catapultRead;
import java.util.ArrayList;

/**
	Compile
		javac -source 6 -target 6 deakin\timo\catapultRead\CatapultOptimEyeRead.java
*/

public class CatapultOptimEyeRead{
/*
	private short[][] codes = {	{0xA5,0x10},
								{0xA6,0x10},
								{0x6D,0xBC},
								{0x7F,0x13}
								};
								*/
	private int[] packetLengths = {	2+139,
									2+19,
									2+21,
									2+21
									};
	private ArrayList<Short> counters;
	private ArrayList<Short>[] data;
	private ArrayList<Double> speed;
	public CatapultOptimEyeRead(byte[] dataIn){
		//System.out.println("IN Optimeye Read");
		counters	= new ArrayList<Short>();
		data		= (ArrayList<Short>[]) new ArrayList[9];
		for (int i = 0; i<data.length;++i){
			data[i] = new ArrayList<Short>();
		}
		speed 		= new ArrayList<Double>();
		/*Go through the data*/
		int i = 0;
		int ignore = 0;

		while (i < dataIn.length-1){
			int cond = (int) (((int) dataIn[i]) & 0xff)<<8 | (((int) dataIn[i+1]) & 0xff);
			//System.out.println("I "+(i+1024)+"Cond "+cond+" GPS field "+0x708C+" hex "+String.format("0x%02x",dataIn[i])+" "+String.format("0x%02x",dataIn[i+1])+" ");
			switch (cond){
				case 0x708C:	//GPS
					//double tempVal = ((double) ((((int) dataIn[i+2+80]) & 0xff) | (((int) dataIn[i+2+80+1] & 0xff) <<8) | (((int) dataIn[i+2+80+2] & 0xff) <<16) | (((int) dataIn[i+2+80+6] & 0xff) <<24)));
					//System.out.println(String.format("GPS 0x%02x 0x%02x 0x%02x 0x%02x %.1f",dataIn[i+2+80],dataIn[i+2+80+1],dataIn[i+2+80+2],dataIn[i+2+80+3],tempVal));
					speed.add(((double) ((((int) dataIn[i+2+80]) & 0xff) | (((int) dataIn[i+2+80+1] & 0xff) <<8) | (((int) dataIn[i+2+80+2] & 0xff) <<16) | (((int) dataIn[i+2+80+6] & 0xff) <<24)))/1000d);
					i+=packetLengths[0];
					break;
				case 0x7D13:	//IMU
					if (ignore < 50){
						++ignore;
					}else{
						counters.add((short) (((short) dataIn[i+2]) & 0xFF ));	//Get counter value
						String hexVals = "";
						for (int d = 0;d<data.length;++d){
							hexVals+=String.format("0x%02x",dataIn[i+3+(2*d)])+" "+String.format("0x%02x",dataIn[i+3+(2*d+1)])+" ";
							//data[d].add((double) (((int)dataIn[i+3+(2*d)])<<8 | ((int) dataIn[i+3+(2*d+1)])));
							//data[d].add((double) (((int)dataIn[i+3+(2*d)]) | ((int) dataIn[i+3+(2*d+1)])<<8));
							//data[d].add((double) ((short) ((((short) dataIn[i+3+(2*d)]) & 0xff) | ((short) ((short) dataIn[i+3+(2*d+1)] & 0xff))<<8)));
							data[d].add((short) ((short) ((((short) dataIn[i+3+(2*d)]) & 0xff) | ((short) ((short) dataIn[i+3+(2*d+1)] & 0xff))<<8)));
						}
						//System.out.println("Line "+counters.size()" "+hexVals);
					}
					i+=packetLengths[1];
					break;
				case 0x2016:	//GPS date
					i+=packetLengths[2];
					break;
				case 0x2018:	//GPS time
					i+=packetLengths[3];
					break;
				default:
					++i;
					break;
			}
		}
	}
	
	public short[][] getData(){
		short[][] returnData = new short[data.length][data[0].size()];
		//System.out.println("ReturnSize "+returnData.length+" "+returnData[0].length);
		for (int i = 0; i<data.length;++i){
			//System.out.println("dataLength "+data[i].size());
			for (int j = 0; j<data[i].size();++j){
				returnData[i][j] = data[i].get(j);
			}
		}
		return returnData;
	}
	
	public double[] getSpeed(){
		double[] returnData = new double[speed.size()];
		//System.out.println("ReturnSize "+returnData.length+" "+returnData[0].length);
		for (int i = 0; i<speed.size();++i){
			returnData[i] = speed.get(i);
		}
		return returnData;
	}
	
	public short[] getCounters(){
		short[] count = new short[counters.size()];
		//System.out.println("Counter size "+count.length);
		for (int i = 0; i<counters.size();++i){
			count[i] =  counters.get(i);
		}
		return count;
	}
}