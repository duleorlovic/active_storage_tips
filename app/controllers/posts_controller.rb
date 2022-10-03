class PostsController < ApplicationController
  def index
    @posts = Post.all
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.create! _post_params
    redirect_to posts_path
  end

  def edit
    @post = Post.find params[:id]
  end

  def update
    @post = Post.find params[:id]
    @post.update! _post_params
    redirect_to posts_path
  end

  def _post_params
    params.require(:post).permit(:content)
  end
end
