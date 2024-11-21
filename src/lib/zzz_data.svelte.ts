// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Zzz_Data_Json {}

export class Zzz_Data {
	show_main_menu = $state(false);

	toJSON(): Zzz_Data_Json {
		return {
			show_main_menu: this.show_main_menu,
		};
	}

	// TODO pluggable mutations
	toggle_main_menu(value: boolean = !this.show_main_menu): boolean {
		this.show_main_menu = value;
		return value;
	}
}
