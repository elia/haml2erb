require 'spec_helper'

haml = %{
!!!
%html(lang="en")
  %head
    - ciao
    - if 3
      = pippo
    - else
      = caio

    %meta(charset="utf-8")
    %meta(content="IE=edge,chrome=1" http-equiv="X-UA-Compatible")
    = csrf_meta_tags

    %title Doomboard!

    / Mobile viewport optimized: j.mp/bplateviewport
    %meta(content="width=device-width,initial-scale=1" name="viewport")

    = javascript_include_tag 'http://js.pusherapp.com/1.9/pusher.min.js'
    = stylesheet_link_tag    'application'
    = javascript_include_tag 'application'

  %body
    %aside.left
      %section#leaderboard(data-widget="leaderboard")
      %section#dr_doomboard(data-widget="dr_doomboard")

    %section#projects
      - [1,2,3].each do |n|
        = n
      - 1234
    %aside.right
      %section#tweets(data-widget="twitter")
      %section#hammurabi
}

erb = %{<!DOCTYPE html>
<html lang='en'>
  <head>
    <% ciao %>
    <% if 3 %>
      <%= pippo %>
    <% else %>
      <%= caio %>
    <% end %>
    <meta charset='utf-8'>
    <meta content='IE=edge,chrome=1' http-equiv='X-UA-Compatible'>
    <%= csrf_meta_tags %>
    <title>Doomboard!</title>
    <!-- Mobile viewport optimized: j.mp/bplateviewport -->
    <meta content='width=device-width,initial-scale=1' name='viewport'>
    <%= javascript_include_tag 'http://js.pusherapp.com/1.9/pusher.min.js' %>
    <%= stylesheet_link_tag    'application' %>
    <%= javascript_include_tag 'application' %>
  </head>
  <body>
    <aside class='left'>
      <section data-widget='leaderboard' id='leaderboard'></section>
      <section data-widget='dr_doomboard' id='dr_doomboard'></section>
    </aside>
    <section id='projects'>
      <% [1,2,3].each do |n| %>
        <%= n %>
      <% end %>
      <% 1234 %>
    </section>
    <aside class='right'>
      <section data-widget='twitter' id='tweets'></section>
      <section id='hammurabi'></section>
    </aside>
  </body>
</html>
}


describe 'haml2erb' do
  it 'converts to ERB' do
    Haml2Erb.convert(haml).should eq(erb)
  end
end
