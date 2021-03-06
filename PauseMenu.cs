using Godot;
using System;

public class PauseMenu : Popup
{
	// Declare member variables here. Examples:
	// private int a = 2;
	// private string b = "text";
	private bool pauseGame = false;
	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		
	}
	//escape pressed
	public override void _Process(float delta)
	{
		if (Input.IsActionJustPressed("ui_cancel")){
		  if(!pauseGame){
							 
				Show();
				pauseGame = true;
				GetTree().Paused = true;
				
			}          
			else{                
				Hide();
				GetTree().Paused = false;
				pauseGame = false;
			}
		}
	}
	//GUI button events for popup
	//continue
	public void _on_Continue_gui_input(InputEvent @event){
		if (@event is InputEventMouseButton mbe && mbe.ButtonIndex == (int)ButtonList.Left && mbe.Pressed)
		{
			Hide();
			GetTree().Paused = false;
			pauseGame = false;
		}
	}
	//Options
	public void _on_Options_gui_input(InputEvent @event){
		if (@event is InputEventMouseButton mbe && mbe.ButtonIndex == (int)ButtonList.Left && mbe.Pressed)
		{
	  return;
		}
	}
	//Save game
	public void _on_Save_gui_input(InputEvent @event){
		if (@event is InputEventMouseButton mbe && mbe.ButtonIndex == (int)ButtonList.Left && mbe.Pressed)
		{
			State.Save();
		}
	}      
	//Load game
	public void _on_Load_gui_input(InputEvent @event){
		if (@event is InputEventMouseButton mbe && mbe.ButtonIndex == (int)ButtonList.Left && mbe.Pressed)
		{
			if (State.Load())
				GetTree().ChangeScene("res://level_select.tscn");
		}
	}

	//exit
	public void _on_Exit_gui_input(InputEvent @event){
		if (@event is InputEventMouseButton mbe && mbe.ButtonIndex == (int)ButtonList.Left && mbe.Pressed)
		{
			//Add a confirm
			GetTree().Paused = false;
			pauseGame = false;
			GetTree().ChangeScene("res://MainMenu.tscn");
		}
	}
}
