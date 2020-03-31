/*
 * Author:	Dmitriy 'Balmer' Poskryakov
 * Created:	2020
 * License: MIT License
*/

module sdio_slave(
	input bit clock,
	input bit sd_clock,
	inout wire sd_serial,
	inout wire[3:0] sd_data,
	
	//Количество данных, которые требуется передать или принять
	output bit[8:0] data4_count,
	output bit write_data4_strobe,
	output bit read_data4_strobe
);

bit write_enabled;
bit sd_serial_out;
assign sd_serial = write_enabled?sd_serial_out:1'bz;

bit write_enabled4;
bit[3:0] sd_data_out;
assign sd_data = write_enabled4?sd_data_out:4'bz;

//Данные прочитанные из sdio command line
bit[37:0] read_data;
bit read_data_strobe;
bit read_error;

//Данные, которые следует отослать по sdio command line
bit[37:0] write_data;
bit write_data_strobe;

bit read_disabled; //Пока 1 - нельзя передавать команды
bit read_disabled4; //Пока 1 - нельзя передавать данные

bit write_all_strobe4;
bit crc_ok4;
bit start_send_crc_status = 0;
bit crc_status;


sd_response_stream response(
	.clock(clock),
	.data(write_data),
	.data_strobe(write_data_strobe),
	.sd_clock(sd_clock),
	.sd_serial(sd_serial_out),
	.write_enabled(write_enabled),
	.read_disabled(read_disabled)
);

sd_read_stream read(
	.clock(clock),
	.sd_clock(sd_clock),
	.sd_serial(sd_serial),
	.read_enabled(~read_disabled),
	.data(read_data),
	.data_strobe(read_data_strobe),
	.read_error(read_error)
);

bit[8:0] write_count = 0;
bit start_write = 0;
bit data_empty;
bit data_strobe;
bit data_req;
byte data;

sd_response_stream_dat response_dat(
	.clock(clock),
	
	.start_write(start_write),
	
	.data_req(data_req),
	.data_empty(data_empty),
	.data_strobe(data_strobe),
	.data(data),
	
	.start_send_crc_status(start_send_crc_status),
	.crc_status(crc_status),
	
	.sd_clock(sd_clock), //Передаем бит, когда clock falling
	.sd_data(sd_data_out), //Пин, через который передаются данные
	.write_enabled(write_enabled4), //Пока передаются данные write_enabled==1 (переключение inout получается уровнем выше)
	.read_disabled(read_disabled4)
);

sd_read_stream_dat read_dat(
	.clock(clock),
	.sd_clock(sd_clock),
	.sd_data(sd_data),
	
	.read_strobe(read_data4_strobe),
	.data_count(data4_count),
	
	.write_byte_strobe(),
	.byte_out(),
	.write_all_strobe(write_all_strobe4),
	.crc_ok(crc_ok4)
);


sdio_commands_processor sdio_commands(
	.clock(clock),
	
	.read_data(read_data),
	.read_data_strobe(read_data_strobe),
	.read_error(read_error),
	
	.write_data(write_data),
	.write_data_strobe(write_data_strobe),
	
	.write_data4_strobe(write_data4_strobe),
	.read_data4_strobe(read_data4_strobe),
	.data4_count(data4_count),
	
	.send_command_in_progress(read_disabled),
	.send_data_in_progress(read_disabled4)
);


//Временный код, чтобы передать данные.
always @(posedge clock)
begin
	start_send_crc_status <= 0;

	start_write <= 0;
	data_strobe <= 0;
	if(write_data4_strobe)
	begin
		write_count <= data4_count;
		start_write <= 1'd1;
		data_empty <= 0;
	end
	
	if(data_req)
	begin
		if(write_count>0)
		begin
			data <= write_count[7:0]+8'h35;
			data_strobe <= 1'd1;
			write_count <= write_count-1'd1;
		end
		else
		begin
			data_empty <= 1'd1;
		end
	end

	//Передаём ответ, что мы приняли данные
	if(write_all_strobe4)
	begin
		start_send_crc_status <= 1'd1;
		crc_status <= crc_ok4;
	end
end

endmodule
