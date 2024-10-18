// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Zzz_Data_Json {}

// TODO rename to `Ui_State` or `Ui` or something?
export class Zzz_Data {
	show_main_menu = $state(false);

	toJSON(): Zzz_Data_Json {
		return {
			show_main_menu: this.show_main_menu,
		};
	}
}
