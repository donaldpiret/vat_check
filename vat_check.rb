# VAT Check Version 0.1 Copyright (c) 2006, Donald Piret
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted 
# provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice, this list of 
#      conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of 
#      conditions and the following disclaimer in the documentation and/or other materials provided 
#      with the distribution.
#    * Neither the name of Synergetek, nor the names of its contributors may be used to 
#      endorse or promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR 
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND 
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# If you use this library with a commercial purpose, please consider making a donation to
# paypal@synergetek.be
# Validation algorithms by the Javascript vat checker by John Gardner

module VatCheck

  VATCHECKWSDL = "http://ec.europa.eu/taxation_customs/vies/api/checkVatPort?wsdl"
  
  VATFORMATS = [
    /^(AT)U(\d{8})$/,                     #Austria
    /^(BE)(\d{9}\d?)$/,                   #Belgium
    /^(CY)\d{8}[A-Z]$/,                   #Cyprus
    /^(CZ)(\d{8,10})(\d{3})?$/,           #Check republic
    /^(DK)((\d{8}))$/,                    #Denmark
    /^(EE)(\d{9})$/,                      #Estonia
    /^(FI)(\d{8})$/,                      #Finland
    /^(FR)(\d{11})$/,                     #France 1
    /^(FR)[(A-H)|(J-N)|(P-Z)]\d{10}$/,    #France 2
    /^(FR)\d[(A-H)|(J-N)|(P-Z)]\d{9}$/,   #France 3
    /^(FR)[(A-H)|(J-N)|(P-Z)]{2}\d{9}$/,  #France 4
    /^(DE)(\d{9})$/,                      #Germany
    /^(EL)(\d{8,9})$/,                    #Greece
    /^(HU)(\d{8})$/,                      #Hungary
    /^(IE)(\d{7}[A-W])$/,                 #Ireland 1
    /^(IE)([7-9][A-Z]\d{5}[A-W])$/,       #Ireland 2
    /^(IT)(\d{11})$/,                     #Italy
    /^(LV)(\d{11})$/,                     #Latvia
    /^(LT)(\d{9}|\d{12})$/,               #Lithuania
    /^(LU)(\d{8})$/,                      #Luxemburg
    /^(MT)(\d{8})$/,                      #Malta
    /^(NL)(\d{9})B\d{2}$/,                #Netherlands
    /^(PL)(\d{10})$/,                     #Poland
    /^(PT)(\d{9})$/,                      #Portugal
    /^(RO)(\d{10})$/,                     #Romania
    /^(SL)(\d{8})$/,                      #Slovenia
    /^(SK)(\d{9}|\d{10})$/,               #Slovakia
    /^(ES)([A-Z]\d{8})$/,                 #Spain 1
    /^(ES)(\d{8}[A-Z])$/,                 #Spain 2
    /^(ES)([A-Z]\d{7}[A-Z])$/,            #Spain 3
    /^(SE)(\d{10}\d[1-4])$/,              #Sweden
    /^(GB)(\d{9})$/,                     #UK 1
    /^(GB)(\d{9})\d{3}$/,                #UK 2
    /^(GB)GD\d{3}$/,                     #UK 3
    /^(GB)HA\d{3}$/                      #UK 4
  ]
  
  # Check if the vat number is valid
  def self.is_valid_vat?(vat_number, default_country = "")
    vat_number = clean_up_vat(vat_number)
    valid_format = is_valid_format_vat?(vat_number, default_country)
    assigned_vat = is_assigned_vat?(vat_number, default_country)
    if assigned_vat == true
      puts "Error in Validation function" if not valid_format
      return true
    elsif assigned_vat == false
      return false
    elsif assigned_vat.nil?
      # Could not check if it's an assigned vat, so rely on check formats
      return valid_format
    end
  end

private

  def is_assigned_vat?(vat_number, default_country)
    if result = format_vat(vat_number, default_country)
      require 'soap/wsdlDriver'
      # Create a class customized for the web service
      soap = SOAP::WSDLDriverFactory.new(VATCHECKWSDL).create_rpc_driver
      ## Enable the dumping of soap response to file
      #soap.wiredump_file_base = "soapresult"
      # Create the parameters for the request
      param = {"countryCode" => result[0], "vatNumber" => result[1]}
      # Send the request
      begin
        result = soap.checkVat(param)
      rescue
        return nil
      end
      if result.valid == true.to_s
        return true
      end
    end
    return false
  end

  def is_valid_format_vat?(vat_number, default_country)
    if result = format_vat(vat_number, default_country)
      # Check the thing against appropriate format algorithm
      begin
        return self.send("validate" + result[0], result[1])
      rescue NoMethodError
        # Could not find validation method, so just assume its correct format
        return true
      end
    end
    return false
  end
  
  # Split up VAT in an array of Country code and actual number
  def format_vat(vat_number, default_country)
    VATFORMATS.each do |vat_format|
      if vat_number =~ vat_format
        return [$1,$2]
      end
    end
    return format_vat(default_country + vat_number, "") if not default_country.empty?
    return false
  end
  
  def clean_up_vat(string)
    string.chomp!(' ')
    string.chomp!('-')
    string.chomp!(',')
    string.chomp!('.')
    return string.upcase
  end
  
  # Check check digits of Austrian VAT number
  def validateAT(vat_number)
    multipliers = [1,2,1,2,1,2,1]
    total = 0
    # Extract the next digit and multiply it by the appropriate multiplier
    0.upto(6) do |i|
      temp = vat_number[i,1].to_i * multipliers[i]
      if temp > 9
        total += (temp/10) + (temp%10)
      else
        total += temp
      end
    end
    # Establish Check digit
    total = 10 - ((total + 4) % 10)
    total = 0 if total == 10
    # Compare it with the last character of the VAT number. If it is the same, 
    # then it's a valid check digit.
    return true if total == vat_number[7..1].to_i
    return false
  end
  
  # Check check digits for Belgian VAT number
  def validateBE(vat_number)
    # Nine digit numbers have a 0 inserted at the front
    vat_number = ("0" + vat_number.to_s) if vat_number.to_S.length == 9
    # Check digits
    return true if (97 - vat_number[0..8].to_i) % 97 == vat_number[8..10].to_i
    return false
  end
  
  # Check the check digits for a Czech Republic VAT number
  def validateCZ(vat_number)
    total = 0
    multipliers = [8,7,6,5,4,3,2]
    # Only do check digit validation for standard VAT numbers
    return true unless vat_number.to_s.length == 8
    # Multiply by multipliers
    0.upto(6) do |i|
      total = total + vat_number[i,1].to_i * multipliers[i] 
    end
    # Establish Check digit
    total = 11 - total % 11
    total = 0 if total == 10
    total = 1 if total == 11
    # Compare with last character of the VAT number.
    return true if total == vat_number.to_s.slice(7..8).to_i
    return false
  end
  
  # Check the check digit for a German VAT number
  def validateDE(vat_number)
    product = 10
    sum = 0
    checkdigit = 0
    0.upto(7) do |i|
      # Extract the next digit and implement peculiar algorithm
      sum = (vat_number[i,1].to_i + product) % 10
      sum = 10 if sum == 0
      product = (2 * sum) % 11
    end
    # Establish check digit
    if (11 - product == 10)
      checkdigit = 0
    else
      checkdigit = 11 - product
    end
    # Compare it with the last two chars of the VAT number
    return true if checkdigit == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Danish VAT number
  def validateDK(vat_number)
    total = 0
    multipliers = [2,7,6,5,4,3,2,1]
    0.upto(7) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    return true if (total % 11 == 0)
    return false
  end
  
  # Check the check digit for an Estonian VAT number
  def validateEE(vat_number)
    total = 0
    multipliers = [3,7,1,3,7,1,3,7]
    0.upto(7) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = 10 - total % 10
    total = 0 if total == 10
    return true if total == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Greek VAT number
  def validateEL(vat_number)
    total = 0
    multipliers = [256,128,64,32,16,8,4,2]
    vat_number = ("0" + vat_number.to_s) if vat_number.to_S.length == 8
    0.upto(7) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = total % 11
    total = 0 if total > 9
    return true if total == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Spanish VAT number
  def validateES(vat_number)
    total = 0
    temp = 0
    multipliers = [2,1,2,1,2,1,2]
    esexp = [/^[A-H]\d{8}$/,/^[N|P|Q|S]\d{7}[A-Z]$/]
    0.upto(6) do |i|
      temp = vat_number[i + 1].to_i * multipliers[i]
      if temp > 9
        total += (temp / 10) + (temp % 10)
      else
        total += temp
      end
    end 
    # With profit company
    if not (vat_number =~ esexp[0]).nil?
      # Calculate the check digit
      total = 10 - total % 10
      total = 0 if total == 10
      return true if total == vat_number[8..9].to_i
      return false
    # Non-profit companies
    elsif not (vat_number =~ esexp[1]).nil?
      # Calculate the check digit
      total = 10 - total % 10
      total = (total + 64).chr
      return true if total == vat_number[8..9]
      return false
    end
  end
  
  # Check the check digit for a Finland VAT number
  def validateFI(vat_number)
    total = 0
    multipliers = [7,9,10,5,8,4,2]
    0.upto(6) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish the check digit
    total = 11 - total % 11
    total = 0 if total > 9
    return true if total == vat_number[7..8].to_i
    return false
  end
  
  # Check the check digit for a French VAT number
  def validateFR(vat_number)
    return true if (vat_number =~ /^\d{11}$/).nil?
    total = vat_number[2..11].to_i
    # Establish check digit
    total = (total*100+12) % 97
    return true if total == vat_number[0..2].to_i
    return false
  end
  
  # Check the check digit for a Hungarian VAT number
  def validateHU(vat_number)
    total = 0
    multipliers = [9,7,3,1,9,7,3]
    0.upto(6) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish the check digit
    total = 10 - total % 10
    total = 0 if total == 10
    return true if total == vat_number[7..8].to_i
    return false
  end
  
  # Check the check digit for an Irish VAT number
  def validateIE(vat_number)
    total = 0
    multipliers = [8,7,6,5,4,3,2]
    # If code in the old format convert it to the new
    if vat_number =~ /^\d[A-Z]/
      vat_number = "0" + vat_number[2..7] + vat_number[0..1] + vat_number[7..8]
    end
    0.upto(6) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish the check digit
    total = total % 23
    if total == 0
      total = "W"
    else
      total = (total + 64).chr
    end
    return true if total == vat_number[7..8]
    return false
  end
  
  # Check the check digit for an Italian VAT number
  def validateIT(vat_number)
    total = 0
    multipliers = [1,2,1,2,1,2,1,2,1,2]
    # Last three digits are issuing office, and cannot exceed 201
    temp = vat_number[0..7].to_i
    return false if temp == 0
    temp = vat_number[7..10].to_i
    return false if temp < 1 or temp > 201
    0.upto(9) do |i|
      temp = vat_number[i,1].to_i * multipliers[i]
      if temp > 9
        total += temp / 10 + temp % 10
      else
        total += temp
      end
    end
    # Establish check digit
    total = 10 - total % 10
    total = 0 if total > 9
    return true if vat_number[10..11].to_i == total
    return false
  end
  
  # Check the check digit for a Lithuanian VAT number
  def valitdateLT(vat_number)
    total = 0
    # Validate only standard VAT numbers
    return true unless vat_number.length == 9
    0.upto(7) do |i|
      total += vat_number[i,1].to_i * (i+1)
    end
    if total % 11 == 10
      multipliers = [3,4,5,6,7,8,9,1]
      total = 0
      0.upto(7) do |i|
        total += vat_number[i,1] * multipliers[i]
      end
    end
    # Establish check digit
    total = total % 11
    total = 0 if total == 10
    return true if total == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Luxemburg VAT number
  def validateLU(vat_number)
    return true if vat_number[0..6].to_i % 89 == vat_number[6..8].to_i
    return false
  end
  
  # Check the check digit for a Latvian VAT number
  def validateLV(vat_number)
    # Only check legal bodies
    return true if vat_number =~ /^[0-3]/
    total = 0
    multipliers = [9,1,4,8,3,10,2,5,7,6]
    0.upto(9) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total -= 45 if total % 11 == 4 and vat_number[0,1].to_i == 9
    if total % 11 == 4
      total = 4 - total % 11
    elsif total % 11 > 4
      total = 14 - total % 11
    elsif total % 11 < 4
      total = 3 - total % 11
    end
    return true if total == vat_number[10..11].to_i
    return false
  end
  
  # Check the check digit for a Maltese VAT number
  def validateMT(vat_number)
    total = 0
    multipliers = [3,4,6,7,8,9]
    1.upto(5) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = 37 - total % 37
    return true if total == vat_number[6..8].to_i
    return false
  end
  
  # Check the check digits for a Dutch VAT number
  def validateNL(vat_number)
    total = 0
    multipliers = [9,8,7,6,5,4,3,2]
    0.upto(7) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = total % 11
    total = 0 if total > 9
    return true if total == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Polish VAT
  def validatePL(vat_number)
    total = 0
    multipliers = [6,5,7,2,3,4,5,6,7]
    0.upto(8) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = total % 11
    total = 0 if total > 9
    return true if total == vat_number[9..10].to_i
    return false
  end
  
  # Check the check digit for a Portugese VAT
  def validatePT(vat_number)
    total = 0
    multipliers = [9,8,7,6,5,4,3,2]
    0.upto(7) do |i| 
      total += vat_number[i,1] * multipliers[i]
    end
    # Establish check digit
    total = 11 - total % 11
    total = 0 if total > 9
    return true if total == vat_number[8..9].to_i
    return false
  end
  
  # Check the check digit for a Swedish VAT
  def validateSE(vat_number)
    total = 0
    multipliers = [2,1,2,1,2,1,2,1,2]
    temp = 0
    0.upto(8) do |i|
      temp = vat_number[i,1] * multipliers[i]
      if temp > 9
        total += (temp / 10) + (temp % 10)
      else
        total += temp
      end
    end
    # Establish check digit
    total = 10 - total % 10
    total = 0 if total == 10
    return true if total == vat_number[9..10].to_i
    return false
  end
  
  # Check the check digit of a Slovak VAT
  def validateSK(vat_number)
    total = 0
    multipliers = [8,7,6,5,4,3,2]
    3.upto(8) do |i|
      total += vat_number[i,1].to_i * multipliers[i-3] 
    end
    # Establish check digit
    total = 11 - total % 11
    total -= 10 if total > 9
    return true if total == vat_number[9..10].to_i
    return false
  end
  
  # Check the check digit of a Slovenian VAT
  def validateSL(vat_number)
    total = 0
    multipliers = [8,7,6,5,4,3,2]
    0.upto(6) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = 11 - total % 10
    total = 0 if total > 9
    return true if total == vat_number[7..8].to_i
    return false
  end
  
  # Check the check digit of a UK VAT
  def validateUK(vat_number)
    # Only inspect check digits for 9 character numbers
    return true unless vat_number.length == 9
    total = 0
    multipliers = [8,7,6,5,4,3,2]
    0.upto(6) do |i|
      total += vat_number[i,1].to_i * multipliers[i]
    end
    # Establish check digit
    total = total % 97
    total -= 97 unless total == 0
    total = total.abs
    return true if total == vat_number[7..9].to_i
    return false
  end
  
end