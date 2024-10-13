export interface Zzz_Data_Json {}

export class Zzz_Data {
	show_main_menu = $state(false);

	toJSON(): Zzz_Data_Json {
		return {
			show_main_menu: this.show_main_menu,
		};
	}
}
