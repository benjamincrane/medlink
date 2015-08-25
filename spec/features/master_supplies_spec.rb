require 'spec_helper'

describe "Master Supply List" do
  before :each do
    @supply = create :supply
  end

  it "lets admins view master supply list" do
    admin = create :admin
    login admin
    visit supplies_path

    expect( page ).to have_content @supply.name
    expect( @supply.orderable ).to be true
  end

  it "prevents pcmo's from viewing master supply list" do
    pcmo = create :pcmo
    login pcmo
    visit supplies_path

    expect( alert.text ).to eq "You are not authorized to view that page"
    expect( current_path ).to eq manage_orders_path
  end

  it "prevents pcv's from viewing master supply list" do
    pcv = create :pcv
    login pcv
    visit supplies_path

    expect( alert.text ).to eq "You are not authorized to view that page"
    expect( current_path ).to eq new_request_path
  end

  it "allows admins to toggle orderability" do
    admin = create :admin
    login admin
    visit supplies_path

    within "tbody" do
    end

    expect( Supply.count ).to eq 0
    expect( Supply.unscoped.count ).to eq 1

    #expect row to be class danger
    #expect button icon to change
  end

  describe "amend list" do
    before :each do
      admin = create :admin
      login admin
      visit new_supply_path
    end

    it "allows admins to add new items" do
      within "#new_supply" do
        fill_in "Name", with: "Test Supply"
        fill_in "Shortcode", with: "TEST"
        click_on "Save"
      end

      expect( Supply.last.name ).to eq "Test Supply"
      expect( Supply.count ).to eq 2
    end

    it "does not save items without name" do
      within "#new_supply" do
        fill_in "Name", with: "Test Supply"
        click_on "Save"
      end

      expect( Supply.last.name ).not_to eq "Test Supply"
      expect( Supply.count ).to eq 1
      expect( page.find("#new_supply") ).to have_selector("div", ".form-group has error")
      expect( page.text ).to include "can't be blank"
    end

    it "does not save items without shortcode" do
      within "#new_supply" do
        fill_in "Shortcode", with: "TEST"
        click_on "Save"
      end

      expect( Supply.last.shortcode ).not_to eq "TEST"
      expect( Supply.count ).to eq 1
      expect( page.find("#new_supply") ).to have_selector("div", ".form-group has error")
      expect( page.text ).to include "can't be blank"
    end
  end
end