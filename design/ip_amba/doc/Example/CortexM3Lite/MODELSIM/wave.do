onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb/i1/HADDRI
add wave -noupdate -radix hexadecimal /tb/i1/HTRANSI
add wave -noupdate -radix hexadecimal /tb/i1/HSIZEI
add wave -noupdate -radix hexadecimal /tb/i1/HBURSTI
add wave -noupdate -radix hexadecimal /tb/i1/HPROTI
add wave -noupdate -radix hexadecimal /tb/i1/HRDATAI
add wave -noupdate -radix hexadecimal /tb/i1/HREADYI
add wave -noupdate -radix hexadecimal /tb/i1/HRESPI
add wave -noupdate -radix hexadecimal /tb/i1/HADDRD
add wave -noupdate -radix hexadecimal /tb/i1/HTRANSD
add wave -noupdate -radix hexadecimal /tb/i1/HSIZED
add wave -noupdate -radix hexadecimal /tb/i1/HBURSTD
add wave -noupdate -radix hexadecimal /tb/i1/HPROTD
add wave -noupdate -radix hexadecimal /tb/i1/HWDATAD
add wave -noupdate -radix hexadecimal /tb/i1/HWRITED
add wave -noupdate -radix hexadecimal /tb/i1/HRDATAD
add wave -noupdate -radix hexadecimal /tb/i1/HREADYD
add wave -noupdate -radix hexadecimal /tb/i1/HRESPD
add wave -noupdate -radix hexadecimal /tb/i1/HMASTERD
add wave -noupdate -radix hexadecimal /tb/i1/HADDRS
add wave -noupdate -radix hexadecimal /tb/i1/HTRANSS
add wave -noupdate -radix hexadecimal /tb/i1/HWRITES
add wave -noupdate -radix hexadecimal /tb/i1/HSIZES
add wave -noupdate -radix hexadecimal /tb/i1/HWDATAS
add wave -noupdate -radix hexadecimal /tb/i1/HBURSTS
add wave -noupdate -radix hexadecimal /tb/i1/HPROTS
add wave -noupdate -radix hexadecimal /tb/i1/HREADYS
add wave -noupdate -radix hexadecimal /tb/i1/HRDATAS
add wave -noupdate -radix hexadecimal /tb/i1/HRESPS
add wave -noupdate -radix hexadecimal /tb/i1/HMASTERS
add wave -noupdate -radix hexadecimal /tb/i1/HMASTERLOCKS
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {207 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 167
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1536 ps}
