// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface Zzz_Data_Json {}

// TODO BLOCK rename to `Ui_State` or `Ui` or something? also make Serializable
export class Zzz_Data {
	show_main_dialog = $state(false);

	toJSON(): Zzz_Data_Json {
		return {
			show_main_dialog: this.show_main_dialog,
		};
	}

	// TODO pluggable mutations
	toggle_main_menu(value: boolean = !this.show_main_dialog): boolean {
		this.show_main_dialog = value;
		return value;
	}
}
