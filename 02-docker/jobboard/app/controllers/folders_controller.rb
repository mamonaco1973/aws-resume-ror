class FoldersController < ApplicationController
  def index
    skip_authorization
    @folders = current_user.folders.order(:name)
  end

  def new
    authorize Folder
    @folder = Folder.new
  end

  def create
    authorize Folder
    @folder = current_user.folders.build(folder_params)
    if @folder.save
      redirect_to folders_path, notice: "Folder created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @folder = current_user.folders.find(params[:id])
    authorize @folder
    @folder.destroy
    redirect_to folders_path, notice: "Folder deleted. Jobs were unassigned."
  end

  private

  def folder_params
    params.require(:folder).permit(:name)
  end
end
